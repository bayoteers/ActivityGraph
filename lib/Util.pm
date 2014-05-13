# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.
#
# Copyright (C) 2014 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jolla.com>

package Bugzilla::Extension::ActivityGraph::Util;
use strict;
use warnings;

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Install::Filesystem;
use Bugzilla::Util qw(datetime_from trick_taint);
use Bugzilla::Error;
use Bugzilla::Status;

use Cwd qw(abs_path);
use File::Basename qw(fileparse);
use File::Temp;
use List::Util qw(min);

use base qw(Exporter);
our @EXPORT = qw(
    activity_graph
);


sub AddLink {
    my ($blocked, $dependson, $fh, $edgesdone, $seen) = (@_);
    my $key = "$blocked,$dependson";
    if (!exists $edgesdone->{$key}) {
        $edgesdone->{$key} = 1;
        print $fh "$dependson -> $blocked\n";
        $seen->{$blocked} = 1;
        $seen->{$dependson} = 1;
    }
}

sub activity_graph {
    my $vars = shift;

    my $dbh = Bugzilla->dbh;
    my $blocks = grep($_ eq $vars->{activity_inlcude}, qw(blocks all));
    my $dependson = grep($_ eq $vars->{activity_inlcude}, qw(dependson all));
    my %baselist;
    my %buginfo;
    for my $bug (@{$vars->{bugs}}) {
        $buginfo{$bug->{bug_id}} = $bug;
        $baselist{$bug->{bug_id}} = 1;
    }
    my $dot = Bugzilla->params->{'webdotbase'};
    ThrowCodeError('activitygraph_no_graphs') unless $dot;
    # TODO: Add webdot support
    ThrowCodeError('activitygraph_no_webdot') unless ($dot =~ /^\//);

    my $webdotdir = bz_locations()->{'webdotdir'};

    my ($fh, $dotfilename) = File::Temp::tempfile("jh_XXXXXXXXXX",
                                               SUFFIX => '.dot',
                                               DIR => $webdotdir,
                                               UNLINK => 0);

    chmod Bugzilla::Install::Filesystem::CGI_WRITE, $dotfilename
        or warn install_string('chmod_failed', { path => $dotfilename,
                                                 error => $! });

    my $urlbase = Bugzilla->params->{'urlbase'};

    print $fh qq/digraph G {
    graph [rankdir=LR, bgcolor="transparent"];

    node [URL="${urlbase}show_bug.cgi?id=\\N", style=filled, fillcolor=lightgrey];
    /;

    my @stack = keys(%baselist);
    my %seen;
    my %edgesdone;

    my @blocker_stack = $dependson ? @stack : ();
    foreach my $id (@blocker_stack) {
        my $blocker_ids = Bugzilla::Bug::EmitDependList('blocked', 'dependson', $id);
        foreach my $blocker_id (@$blocker_ids) {
            push(@blocker_stack, $blocker_id) unless $seen{$blocker_id};
            AddLink($id, $blocker_id, $fh, \%edgesdone, \%seen);
        }
    }
    my @dependent_stack = $blocks ? @stack : ();
    foreach my $id (@dependent_stack) {
        my $dep_bug_ids = Bugzilla::Bug::EmitDependList('dependson', 'blocked', $id);
        foreach my $dep_bug_id (@$dep_bug_ids) {
            push(@dependent_stack, $dep_bug_id) unless $seen{$dep_bug_id};
            AddLink($dep_bug_id, $id, $fh, \%edgesdone, \%seen);
        }
    }

    foreach my $k (keys(%baselist)) {
        $seen{$k} = 1;
    }

    my $sth = $dbh->prepare(
                  q{SELECT bug_status, resolution, short_desc, TIMESTAMP(delta_ts)
                      FROM bugs
                     WHERE bugs.bug_id = ?});
    my $now = time();
    my @closed = reverse map {$_->name} Bugzilla::Status::closed_bug_statuses();
    my %graph_colours = map {$closed[$_] => $_ / $#closed * 0.6 + 0.2} (0..$#closed);
    foreach my $k (keys(%seen)) {
        # Retrieve bug information from the database
        my ($status, $resolution, $summary, $delta) = $dbh->selectrow_array($sth, undef, $k);

        my $tooltip = "";
        # Resolution and summary are shown only if user can see the bug
        if (Bugzilla->user->can_see_bug($k)) {
            # Wide characters cause GraphViz to die.
            if (Bugzilla->params->{'utf8'}) {
                utf8::encode($summary) if utf8::is_utf8($summary);
            }
            $summary =~ s/([\\\"])/\\$1/g;
            $tooltip = "$status $resolution $summary";
        }

        my @params;

        if ($tooltip ne "") {
            push(@params, qq{label="$k"});
            push(@params, qq{tooltip="$tooltip"});
        }

        if (exists $baselist{$k}) {
            push(@params, ("shape=box", "color=black", "penwidth=2"));
        }

        if (defined $graph_colours{$status}) {
            push(@params, 'fillcolor="0 0 '.$graph_colours{$status}.'"');
        } else {
            $delta = ($now - datetime_from($delta)->epoch) / 604800;
            $delta = min($delta, 4) / 4;
            my $hue = 0.33 - (0.33 * $delta);
            push(@params, "fillcolor=\"$hue 1 1\"");
        }

        if (@params) {
            print $fh "$k [" . join(',', @params) . "]\n";
        } else {
            print $fh "$k\n";
        }
    }


    print $fh "}\n";
    close $fh;

    # First, generate the png image file from the .dot source
    my($filebase, $path) = fileparse($dotfilename, qr/\..*/);
    my $pngfilename = "$path/$filebase.png";
    my $mapfilename = "$path/$filebase.map";

    system($dot, "-Tpng", "-o$pngfilename",
        "-Tcmapx", "-o$mapfilename", $dotfilename);

    chmod Bugzilla::Install::Filesystem::WS_SERVE, $pngfilename
        or warn install_string('chmod_failed', { path => $pngfilename,
                                                 error => $! });
    chmod Bugzilla::Install::Filesystem::WS_SERVE, $mapfilename
        or warn install_string('chmod_failed', { path => $mapfilename,
                                                 error => $! });
    # Under mod_perl, pngfilename will have an absolute path, and we
    # need to make that into a relative path.
    my $cgi_root = bz_locations()->{cgi_path};
    $pngfilename =~ s#^\Q$cgi_root\E/?##;
    $mapfilename = abs_path($mapfilename);

    $vars->{image_url} = $pngfilename;
    $vars->{image_map} = $mapfilename;

    $vars->{graph_colours} =
        [map {[$_, $graph_colours{$_}]} keys %graph_colours];
    cleanup_dotdir();
}

sub cleanup_dotdir {
    my $webdotdir = bz_locations()->{'webdotdir'};
    # Cleanup any old .dot files created from previous runs.
    my $since = time() - 24 * 60 * 60;
    # Can't use glob, since even calling that fails taint checks for perl < 5.6
    opendir(my $dh, $webdotdir) or do {
        warn "Failed to open webdot dir '$webdotdir' for reading: $!";
        return;
    };
    my @files = grep { /jh_.*(\.dot$|\.png$|\.map)$/ && -f "$webdotdir/$_" } readdir($dh);
    closedir($dh);
    foreach my $f (@files)
    {
        $f = "$webdotdir/$f";
        # Here we are deleting all old files. All entries are from the
        # $webdot directory. Since we're deleting the file (not following
        # symlinks), this can't escape to delete anything it shouldn't
        # (unless someone moves the location of $webdotdir, of course)
        trick_taint($f);
        if ((stat($f))[9] < $since) {
            unlink $f;
        }
    }
}

1;