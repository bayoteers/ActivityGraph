# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.
#
# Copyright (C) 2014 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jolla.com>

package Bugzilla::Extension::ActivityGraph;
use strict;
use warnings;
use base qw(Bugzilla::Extension);

use Bugzilla::Extension::ActivityGraph::Util;

use Bugzilla::Util qw(datetime_from);

our $VERSION = '0.01';

sub buglist_columns {
    # Most likely works only on Mysql
    return unless Bugzilla->dbh->isa('Bugzilla::DB::Mysql');
    my ($self, $args) = @_;
    $args->{columns}->{days_since_activity} = {
        'title' => 'Since activity',
        'name' => 'TIMESTAMPDIFF(SECOND, bugs.ag_activity_ts, NOW()) / 86400'
    };
}

sub colchange_columns {
    # Most likely works only on Mysql
    return unless Bugzilla->dbh->isa('Bugzilla::DB::Mysql');
    my ($self, $args) = @_;
    push @{$args->{columns}}, 'days_since_activity';
}

sub config_add_panels {
    my ($self, $args) = @_;
    my $modules = $args->{panel_modules};
    $modules->{ActivityGraph} = "Bugzilla::Extension::ActivityGraph::Params";
}

sub install_update_db {
    my ($self, $args) = @_;
    my $dbh = Bugzilla->dbh;
    my $activity_col = $dbh->bz_column_info('bugs', 'ag_activity_ts');
    if (!defined $activity_col) {
        $dbh->bz_add_column('bugs', 'ag_activity_ts', {TYPE => 'DATETIME'});
        $dbh->do('UPDATE bugs SET ag_activity_ts = delta_ts');
    }

}

sub object_columns {
    my ($self, $args) = @_;
    if ($args->{class}->isa('Bugzilla::Bug')) {
        push(@{$args->{columns}}, 'ag_activity_ts');
    }
}

sub bug_end_of_create {
    my ($self, $args) = @_;
    my ($bug, $timestamp) = @$args{qw(bug timestamp)};
    Bugzilla->dbh->do("UPDATE bugs SET ag_activity_ts = ? WHERE bug_id = ?",
                        undef, $timestamp, $bug->id);
}

sub bug_end_of_update {
    my ($self, $args) = @_;
    my ($bug, $changes, $timestamp) = @$args{qw(bug changes timestamp)};
    # TODO: Make the significant fields configurable
    if ($bug->{added_comments}
        || defined $changes->{bug_status}
        || defined $changes->{resolution}
        || defined $changes->{work_time}
        || defined $changes->{see_also})
    {
        Bugzilla->dbh->do("UPDATE bugs SET ag_activity_ts = ? WHERE bug_id = ?",
                            undef, $timestamp, $bug->id);
    }
}



sub template_before_process {
    my ($self, $params) = @_;
    my $file = $params->{file};
    my $vars = $params->{vars};
    if ($file eq 'list/list-activity.html.tmpl') {
        $vars->{activity_inlcude} =
                Bugzilla->cgi->param('activity_include') || 'dependson';
        activity_graph($vars);
    }
}

# Redefine Bugzilla::WebService::Bug::_bug_to_hash to add the custom field
use Bugzilla::WebService::Bug ();
{ no warnings 'redefine';
    *__old_bug_to_hash = \&Bugzilla::WebService::Bug::_bug_to_hash;
    *Bugzilla::WebService::Bug::_bug_to_hash = sub {
        my ($self, $bug, $params) = @_;
        my $result = __old_bug_to_hash(@_);
        $result->{days_since_activity} = $self->type('double', $bug->days_since_activity);
        return $result;
    };
}

BEGIN {
    *Bugzilla::Bug::activity_ts = sub { return $_[0]->{ag_activity_ts}; };

    *Bugzilla::Bug::days_since_activity = sub {
        my $self = shift;
        unless (defined $self->{days_since_activity}) {
            require DateTime;
            my $ts = $self->activity_ts || $self->delta_ts;
            $self->{days_since_activity} =
                (DateTime->now()->epoch - datetime_from($ts)->epoch) / 86400;
        }
        return $self->{days_since_activity};
    };
}

__PACKAGE__->NAME;
