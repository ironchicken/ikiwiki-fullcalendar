#!/usr/bin/perl
# IkiWiki fullcalendar plugin.

# Use the [[!fullcalendar ]] directive to include a calendar in a
# page. The chart itself is rendered using the FullCalendar
# <http://arshaw.com/fullcalendar/> plugin.

# The following parameters are available and their values will be
# supplied directly to the FullCalendar plugin. See its documentation
# for detail: weekends, firstDay, weekMode, weekNumbers, height,
# contentHeight, aspectRatio, year, month, date, timeFormat,
# columnFormat, titleFormat, buttonText, monthNames, monthNamesShort,
# dayNames, dayNamesShort, weekNumberTitle.

# You must provide a unique (per page) id value for each FullCalendar
# on a page.

# A single calendar can include multiple 'event sources'. You must
# provide a pair of parameters for each event source you would like on
# your calendar: ..._desc provides the label for that event source;
# and ..._pages provides a pagespec for the events. The '...'  must be
# a matching identifier for each pair, e.g.:
# 
# [[!fullcalendar project1_desc="Project 1"
#                 project1_pages="tasks/*"]]

# Optionally, you may also provide a ..._class parameter which
# associates a CSS class with that event source.

# The IkiWiki::Plugin::event plugin provides the [[!event ]] and
# [[!period ]] directives for attaching temporal metadata to pages. It
# also provides the pagespec predicates: before; after; between; which
# can be used for matching pages whose temporal metadata fits within
# some constraints.

# An additional `events` parameter can be used to provide JSON-encoded
# events directly to the FullCalendar plugin. These will be rendered
# in addition to the _desc/_pages pairs. See
# <http://arshaw.com/fullcalendar/docs/event_data/events_array/> for
# details on how to encode this data.

# The optional `ics` parameter should be a path under which an ical
# encoding of the events data will be made available. A link to the
# ical will be added below the calendar.

# Copyright (C) 2013 Richard Lewis
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package IkiWiki::Plugin::fullcalendar;

use warnings;
use strict;
use IkiWiki 3.00;
use IkiWiki::Plugin::event qw(find_times);
use JSON;
use Data::ICal;
use Data::ICal::Entry::Event;
use Data::ICal::DateTime;
use File::Spec::Functions qw(splitpath catdir);
use File::Grep qw(fgrep);
use File::Find::Rule;

sub import {
    hook(type => "preprocess", id => "fullcalendar", call => \&fullcalendar);
    hook(type => "needsbuild", id => "fullcalendar", call => \&needsbuild);
    hook(type => "format", id => "fullcalendar", call => \&format);
    hook(type => "savestate", id => "fullcalendar", call => \&savestate);
}

our @FULLCALENDAR_PARAMS = qw(weekends firstDay weekMode weekNumbers height contentHeight aspectRatio year month date timeFormat columnFormat titleFormat buttonText monthNames monthNamesShort dayNames dayNamesShort weekNumberTitle);

sub ics {
    my $page = shift;
    my ($v, $ics_path, $ics_fn) = splitpath(shift);
    my $sources = shift;

    my $calendar = Data::ICal->new;

    while (my ($key, $evt) = each %{$sources}) {
	for my $pg (pagespec_match_list($page, $evt->{pages})) {
	    foreach (@{ &IkiWiki::Plugin::event::find_times($pg) }) {
		my ($span, $attribs, $reason) = @$_;
		next if (!defined $span);

		my $vevt = Data::ICal::Entry::Event->new;
		$vevt->add_properties( summary => $attribs->{desc} || pagetitle($pg) );
		$vevt->start($span->start);
		$vevt->end($span->end);

		$calendar->add_entry($vevt);
	    }
	}
    }

    writefile($ics_fn, catdir($config{destdir}, $ics_path), $calendar->as_string);
    return 1;
}

sub fullcalendar (@) {
    my %params = @_;

    # id parameter is required
    error('fullcalendar directive must have a page-unique id parameter.') unless (exists $params{id});

    # extract the event sources parameters
    my %sources = map { $_ => {desc => $params{$_ . '_desc'}, pages => $params{$_ . '_pages'}, class => $params{$_ . '_class'} } } map { /(.*)_desc/ ? $1 : () } keys %params;

    # ensure the event sources parameters are semantically valid
    return error('Incomplete _desc/_pages pairs.') if (grep { !defined($_->{desc}) || !defined($_->{pages}); } values %sources);

    # generate the event sources JSON
    my $sources_js = [];
    while (my ($key, $evt) = each %sources) {
	my $src = { name      => $key,
		    desc      => $evt->{desc},
		    className => $evt->{class},
		    events    => [] };
	for my $pg (pagespec_match_list($params{page}, $evt->{pages})) {
	    for (@{ &IkiWiki::Plugin::event::find_times($pg) }) {
		my ($span, $attribs, $reason) = @$_;
		next if (!defined $span);

		my $allday = $span->start->hour() == 0 && $span->start->minute() == 0;
		my $multiday = $span->start->day() != $span->end->day();
		my $dt_fmt = ($allday) ? '%Y-%m-%d' : '%Y-%m-%d %H:%M';
		push $src->{events}, { start  => $span->start->strftime($dt_fmt),
				       end    => (!$allday || $multiday) ? $span->end->strftime($dt_fmt) : undef,
				       title  => $attribs->{desc} || pagetitle($pg),
				       allDay => $allday ? 'true' : 'false',
				       url    => $attribs->{url} || "/$pg"};
	    }
	}
	push $sources_js, $src;
    }

    # Add any manually supplied events
    push $sources_js, {events => from_json($params{events} =~ s/'/"/rg)} if (exists $params{events});

    # create .fullcalendar function call
    my $fc = { eventSources => $sources_js,
	       map { (defined $params{$_}) ? ($_ => $params{$_}) : (); } @FULLCALENDAR_PARAMS };
    my $js = '$("#' . $params{id} . '").fullCalendar(' . encode_json($fc) . ');';

    # store the JS for inclusion at format-time
    $pagestate{$params{page}}{fullcalendar}{$params{id}} = $js;

    # insert the FullCalendar HTML
    my $html = '<div id="' . $params{id} . '" class="fullcalendar"></div>';

    # insert the iCal link (if specified)
    if (defined $params{ics}) {
	if (ics $params{page}, $params{ics}, \%sources) {
	    $html .= '<div><a href="' . $params{ics} . '" type="text/calendar"><img src="https://drupal.org/files/issues/ics.png" alt="iCal" /></a></div>';
	}
    }

    return $html;
}

sub needsbuild ($$) {
    my ($altered, $deleted) = @_;

    # FIXME This is the only way I've found to get the fullcalendar
    # preprocess sub to find the pages with !event or !period
    # directives: by forcing all those pages to rebuild
    push $altered, map { $_->{filename} =~ s|$config{srcdir}/?||rg } grep { $_->{count} } fgrep { /\[\[!(event|period|fullcalendar)/ } (File::Find::Rule->file()->name('*.mdwn')->in($config{srcdir}));

    return $altered;
}

sub format (@) {
    my %params = @_;

    if($params{content} =~ m/<div.*class="fullcalendar"/) {
	if(! ($params{content} =~ s!^(</head>)!include_javascript($params{page}).$1!em )) {
	    $params{content} = include_javascript($params{page}, 1).$params{content};
	}
    }
    return $params{content};
}

sub include_javascript ($;$;@) {
    my $page = shift;
    my $abs = shift;
    my %params = @_;

    # FIXME Make these paths wiki config options
    my $html = '<script src="//code.jquery.com/jquery-1.10.2.js" type="text/javascript" charset="utf-8"></script>' . "\n" .
	'<script src="//code.jquery.com/ui/1.10.3/jquery-ui.js" type="text/javascript" charset="utf-8"></script>' . "\n" .
	'<script src="//cdnjs.cloudflare.com/ajax/libs/fullcalendar/1.6.4/fullcalendar.min.js" type="text/javascript" charset="utf-8"></script>' . "\n" .
	'<link rel="stylesheet" type="text/css" href="//cdnjs.cloudflare.com/ajax/libs/fullcalendar/1.6.4/fullcalendar.css" />' . "\n" .
	'<link rel="stylesheet" type="text/css" href="//code.jquery.com/ui/1.10.3/themes/smoothness/jquery-ui.css" />' . "\n";

    if (exists $pagestate{$page}{fullcalendar}) {
	$html .= '<script type="text/javascript">$(document).ready(function(){';
	$html .= join("\n", values $pagestate{$page}{fullcalendar});
	$html .= '});</script>' . "\n";
    }

    return $html;
}

sub savestate {
    for my $page (keys %pagestate) {
	delete($pagestate{$page}{'fullcalendar'}) if (exists $pagestate{$page}{'fullcalendar'});
    }
}

1;
