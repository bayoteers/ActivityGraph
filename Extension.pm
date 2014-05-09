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

our $VERSION = '0.01';

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

__PACKAGE__->NAME;
