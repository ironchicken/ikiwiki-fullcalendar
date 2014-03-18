#!/usr/bin/perl
# IkiWiki event plugin.

# Use the [[!event ]] directive in a page which represents some timed
# event. Its parameters include: timestamp (which will be parsed by
# Date::Parse); duration (optional, a string in the form
# /[0-9]+\s+(days|hours|minutes)/); description (optional, page title
# used by default); location (optional; may be geocoded); show
# (optional, determines whether or not the event should be rendered on
# the page, default is 'no').

# Use the [[!period ]] directive in a page which represents a time
# period. Its parameters include: start_time (which will be parsed by
# Date::Parse); end_time (which will be parsed by Date::Parse);
# description (optional, page title used by default); location
# (optional; may be geocoded); show (optional, determines whether or
# not the period should be rendered on the page, default is 'no').

# This plugin also provides the following pagespec predicates: before;
# after; between. These can be used to select pages having [[!event ]]
# or [[!period ]] metadata which falls within the constraint given
# when the predicate is used.

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

package IkiWiki::Plugin::event;

use warnings;
use strict;
use IkiWiki 3.00;
use DateTime;
use Date::Parse;

BEGIN {
    use Exporter;
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(find_times parse_timestamp);
}

sub import {
    hook(type => "preprocess", id => "event", call => \&event, scan => 1);
    hook(type => "preprocess", id => "period", call => \&period, scan => 1);
    hook(type => "savestate", id => "event", call => sub { unshift @_, 'event'; savestate(@_); });
    hook(type => "savestate", id => "period", call => sub { unshift @_, 'period'; savestate(@_); });
}

our $TZ = DateTime::TimeZone->new(name => 'UTC');

sub parse_timestamp {
    my $timestamp = shift;

    my $time = str2time($timestamp, 0);
    return if (!defined $time);

    my $dt = DateTime->from_epoch(epoch => $time);

    if ($dt->hour() == 0 && $dt->minute() == 0) {
	$dt->truncate(to => 'day');
    }

    return $dt;
}

sub find_times ($) {
    my $page = shift;
    my $events = [];

    sub other_attribs {
	my $obj = shift;
	my $exclude = join '|', @_;
	my $exclude_re = qr/^($exclude)$/;

	my %attribs = ();
	my @keys = grep { $_ !~ $exclude_re } keys $obj;
	@attribs{@keys} = @{ $obj }{@keys};
	return \%attribs;
    }

    # retrieve the event/period parameters
    while (my ($id, $event) = each %{ $IkiWiki::pagestate{$page}{event} }) {
	my ($start_time, $reason);

 	if (exists $event->{timestamp}) {
	    $start_time = parse_timestamp($event->{timestamp});
	} else {
	    $reason = IkiWiki::FailReason->new("event directive missing timestamp parameter");
	}

	my $attribs = other_attribs $event, 'timestamp', 'duration';

	if (defined $event->{duration} && $event->{duration} =~ /([0-9]+)\s+(days|hours|minutes)/) {
	    push($events, [DateTime::Span->from_datetime_and_duration(start => $start_time, $2 => $1), $attribs, $reason]);
	} elsif ($start_time->hour() == 0 && $start_time->minute() == 0) {
	    # default duration for untimed events is 1 day
	    push($events, [DateTime::Span->from_datetime_and_duration(start => $start_time, hours => 23, minutes => 59), $attribs, $reason]);
	} else {
	    # default duration for timed events is 1 hour
	    push($events, [DateTime::Span->from_datetime_and_duration(start => $start_time, hours => 1), $attribs, $reason]);
	}
    }

    while (my ($id, $period) = each %{ $IkiWiki::pagestate{$page}{period} }) {
	my ($start_time, $end_time, $reason);

	if (exists $period->{start_time}) {
	    $start_time = parse_timestamp($period->{start_time});
	} else {
	    $reason = IkiWiki::FailReason->new("period directive missing start_time parameter");
	}
	if (exists $period->{end_time}) {
	    $end_time = parse_timestamp($period->{end_time});
	} else {
	    $reason = IkiWiki::FailReason->new("period directive missing end_time parameter");
	}

	my $attribs = other_attribs $period, 'start_time', 'end_time';

	push $events, [DateTime::Span->from_datetimes(start => $start_time, end => $end_time), $attribs, $reason];
    }

    return $events || [[undef, undef, IkiWiki::FailReason->new("page contains no event/period directives")]];
}

our @REQ_EVENT_PARAMS = qw(timestamp);
our @OPT_EVENT_PARAMS = qw(desc location url);

sub event {
    my %params = @_;
    my $page = $params{page};

    # only store the event when the page is scanned (the hook is run
    # in void context)
    if (!defined wantarray) {
	# set up the events hash for the page
	$pagestate{$page}{event} = {} if (!defined $pagestate{$page}{event});
	my $evt_id = 'event' . (scalar(keys $pagestate{$page}{event}) + 1);
	$pagestate{$page}{event}{$evt_id} = {};# if (!%{ $pagestate{$page}{event}{$evt_id} });

	# store the event parameters
	for (@REQ_EVENT_PARAMS) {
	    if (!defined $params{$_}) { error("Missing $_ parameter"); }
	    else { $pagestate{$page}{event}{$evt_id}->{$_} = $params{$_}; }
	}
	for (@OPT_EVENT_PARAMS) {
	    $pagestate{$page}{event}{$evt_id}->{$_} = $params{$_} if (defined $params{$_});
	}
    }

    if (defined $params{show} && $params{show} =~ /(yes|1)/i) {
	return '<span class="event">' . parse_timestamp($params{timestamp})->strftime('%c') .
	    ((defined $params{desc}) ? " $params{desc}" : '') .
	    '</span>';
    }
}

our @REQ_PERIOD_PARAMS = qw(start_time end_time);
our @OPT_PERIOD_PARAMS = qw(desc location url);

sub period {
    my %params = @_;
    my $page = $params{page};

    # only store the period when the page is scanned (the hook is run
    # in void context)
    if (!defined wantarray) {
	# set up the periods hash for the page
	$pagestate{$page}{period} = {} if (!defined $pagestate{$page}{period});
	my $prd_id = 'period' . (scalar(keys $pagestate{$page}{period}) + 1);
	$pagestate{$page}{period}{$prd_id} = {};# if (!%{ $pagestate{$page}{period}{$prd_id} });

	# store the period parameters
	for (@REQ_PERIOD_PARAMS) {
	    if (!defined $params{$_}) { error("Missing $_ parameter"); }
	    else { $pagestate{$page}{period}{$prd_id}->{$_} = $params{$_}; }
	}
	for (@OPT_PERIOD_PARAMS) {
	    $pagestate{$page}{period}{$prd_id}->{$_} = $params{$_} if (defined $params{$_});
	}
    }

    if (defined $params{show} && $params{show} =~ /(yes|1)/i) {
	return '<span class="period">' . parse_timestamp($params{start_time})->strftime('%c') . '&mdash;' .
	    parse_timestamp($params{end_time})->strftime('%c') .
	    ((defined $params{desc}) ? " $params{desc}" : '') .
	    '</span>';
    }
}

sub savestate {
    my $type = shift;

    for my $page (keys %pagestate) {
	delete($pagestate{$page}{$type}) if (exists $pagestate{$page}{$type});
    }
}

package IkiWiki::PageSpec;

use List::Util qw(reduce);
use Scalar::Util qw(blessed);
use IkiWiki::Plugin::event qw(parse_timestamp);

sub match_before ($$;@) {
    my $page = shift;
    my $argSet = shift;
    my @args = split(/,/, $argSet);
    my $target_date = &IkiWiki::Plugin::event::parse_timestamp(shift @args);

    # Find the minimum start_time from all the events/periods on the
    # page
    my ($span, $attribs, $reason) = reduce { $a->start lt $b->start ? $a : $b } find_times($page);

    return $reason if (blessed $reason, 'FailReason');

    return ($target_date lt $span->start) ?
	IkiWiki::SuccessReason->new("$target_date before " . $span->start) :
	IkiWiki::FailReason->new("$target_date not before " . $span->start);
}

sub match_after ($$;@) {
    my $page = shift;
    my $argSet = shift;
    my @args = split(/,/, $argSet);
    my $target_date = &IkiWiki::Plugin::event::parse_timestamp(shift @args);

    # Find the maximum start_time from all the events/periods on the
    # page
    my ($span, $attribs, $reason) = reduce { $a->start lt $b->start ? $a : $b } find_times($page);

    return $reason if (blessed $reason, 'FailReason');

    return ($target_date gt ($span->end || $span->start)) ?
	IkiWiki::SuccessReason->new("$target_date after " . ($span->end || $span->start)) :
	IkiWiki::FailReason->new("$target_date not after " . ($span->end || $span->start));
}

# FIXME How could between be implemented for pages with multiple
# events/periods?

# sub match_between ($$;@) {
#     my $page = shift;
#     my $argSet = shift;
#     my @args = split(/,/, $argSet);
#     my $period_start = DateTime->from_epoch(epoch => str2time(shift @args, 0), time_zone => $TZ);
#     my $period_end = DateTime->from_epoch(epoch => str2time(shift @args, 0), time_zone => $TZ);

#     my ($start_time, $end_time, $reason) = find_times($page);

#     return $reason if (blessed $reason, 'FailReason');

#     return ($period_start le $start_time && $period_end ge $start_time) ?
# 	IkiWiki::SuccessReason->new("$start_time between $period_start and $period_end") :
# 	IkiWiki::FailReason->new("$start_time not between $period_start and $period_end");
# }

1;
