# IkiWiki FullCalendar Plugin

This package provides two plugins for the
[IkiWiki](http://ikiwiki.info/) software which allow the inclusion of
[calendars](http://arshaw.com/fullcalendar/) on wiki pages drawing
their content from temporal metadata embedded in pages using some new
directives.

## IkiWiki::Plugin::event

Use the `[[!event ]]` directive in a page which represents some timed
event. Its parameters include: timestamp (which will be parsed by
Date::Parse); duration (optional, a string in the form
/[0-9]+\s+(days|hours|minutes)/); description (optional, page title
used by default); location (optional; may be geocoded); show
(optional, determines whether or not the event should be rendered on
the page, default is 'no').

Use the `[[!period ]]` directive in a page which represents a time
period. Its parameters include: start_time (which will be parsed by
Date::Parse); end_time (which will be parsed by Date::Parse);
description (optional, page title used by default); location
(optional; may be geocoded); show (optional, determines whether or not
the period should be rendered on the page, default is 'no').

This plugin also provides the following pagespec predicates: before;
after; between. These can be used to select pages having `[[!event ]]`
or `[[!period ]]` metadata which falls within the constraint given
when the predicate is used.

## IkiWiki::Plugin::fullcalendar

Use the `[[!fullcalendar ]]` directive to include a calendar in a
page. The chart itself is rendered using the FullCalendar
<http://arshaw.com/fullcalendar/> plugin.

The following parameters are available and their values will be
supplied directly to the FullCalendar plugin. See its documentation
for detail: weekends, firstDay, weekMode, weekNumbers, height,
contentHeight, aspectRatio, year, month, date, timeFormat,
columnFormat, titleFormat, buttonText, monthNames, monthNamesShort,
dayNames, dayNamesShort, weekNumberTitle.

You must provide a unique (per page) id value for each FullCalendar
on a page.

A single calendar can include multiple 'event sources'. You must
provide a pair of parameters for each event source you would like on
your calendar: ..._desc provides the label for that event source;
and ..._pages provides a pagespec for the events. The '...'  must be
a matching identifier for each pair, e.g.:

    [[!fullcalendar project1_desc="Project 1"
                    project1_pages="tasks/*"]]

Optionally, you may also provide a ..._class parameter which
associates a CSS class with that event source.

The IkiWiki::Plugin::event plugin provides the `[[!event ]]` and
`[[!period ]]` directives for attaching temporal metadata to pages. It
also provides the pagespec predicates: before; after; between; which
can be used for matching pages whose temporal metadata fits within
some constraints.

An additional `events` parameter can be used to provide JSON-encoded
events directly to the FullCalendar plugin. These will be rendered
in addition to the _desc/_pages pairs. See
<http://arshaw.com/fullcalendar/docs/event_data/events_array/> for
details on how to encode this data.

The optional `ics` parameter should be a path under which an ical
encoding of the events data will be made available. A link to the
ical will be added below the calendar.

## Development

This code has deployed in one (private) wiki and so currently works to
my own satisfaction. Testing, corrections, contributions will be very
welcome.

## License

Copyright © 2013 Richard Lewis

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
