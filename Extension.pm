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
        'name' => 'TIMESTAMPDIFF(SECOND, bugs.delta_ts, NOW()) / 86400'
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
    *Bugzilla::Bug::days_since_activity = sub {
        my $self = shift;
        unless (defined $self->{days_since_activity}) {
            require DateTime;
            $self->{days_since_activity} =
                (DateTime->now()->epoch - datetime_from($self->delta_ts)->epoch) / 86400;

        }
        return $self->{days_since_activity};
    };
}

__PACKAGE__->NAME;
