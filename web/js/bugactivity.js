/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (C) 2014 Jolla Ltd.
 * Contact: Pami Ketolainen <pami.ketolainen@jolla.com>
 */

/*
 * Takes a last change date and returns how many hours/days ago that was and
 * corresponging rgb(r,g,b) color value for that
 */
var calculateActivityInfo = function(days_since_activity) {
    var color = pct2rgb( Math.min(days_since_activity, 14) / 14 )
    color = 'rgb('+color.join(',')+')';
    var rounded = -1;
    var unit = "day";
    if ( days_since_activity > 1) {
        rounded = Math.round(days_since_activity);
    } else if (days_since_activity > 1 / 24) {
        rounded = Math.round(days_since_activity * 24);
        unit = "hour"
    } else {
        rounded = Math.round(days_since_activity * 1440);
        unit = "minute"
    }
    if (rounded != 1)
        unit += "s";
    return {ago: rounded + " " + unit, color: color};
}

/*
 * Convert value between 0-1 to [r,g,b] color between green and red
 */
var pct2rgb = function(pct)
{
    return [
        pct > 0.5 ? 255 : Math.round(255*(pct/0.5)),
        pct < 0.5 ? 255 : Math.round(255*((1 - pct)/0.5)),
        0
    ]
}

/*
 * Event handler for AgileTools buglist additem event for adding the activity
 * indicator
 */
var activityColorOnBugListAdd = function(ev, data)
{
    var activityColor = $("<li></li>");
    var activitInfo = calculateActivityInfo(data.bug.days_since_activity);
    activityColor.css({
        'background-color': activitInfo.color,
        'display': 'inline-block',
        'width': '1em',
        'height': '1em',
        'border-radius': '0.5em',
        'margin': '1px',
    });
    activityColor.attr('title', "Touched " + activitInfo.ago + " ago");
    data.element.find("ul.blitem-summary").first().prepend(activityColor);
}

/*
 * Bug list table column formatter
 */
var buglistActivityColumnFormat = function() {
    $("table.bz_buglist td.bz_days_since_activity_column").each(function()
    {
        var element = $(this);
        var days = Number(element.text().trim());
        if (isNaN(days)) return;
        var info = calculateActivityInfo(days);
        element.css({
            'background-color': info.color,
            'color': 'black'
        });
        element.text(info.ago);
    })
}
