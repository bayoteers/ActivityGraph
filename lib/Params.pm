# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2014 Jolla Ltd.
# Contact: Pami Ketolainen <pami.ketolainen@jolla.com>

package Bugzilla::Extension::ActivityGraph::Params;
use strict;
use warnings;

use Bugzilla::Config::Common qw(check_numeric);

sub get_param_list {
    return ({
            name => 'activitycolorsinplanning',
            type => 'b',
            default => 0,
        }, {
            name => 'activitygraphdayslimit',
            type => 't',
            default => '14',
            checker => \&check_numeric
        }, {
            name => 'activitybuglistdayslimit',
            type => 't',
            default => '14',
            checker => \&check_numeric
        },
    );
}

1;
