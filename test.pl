#!/usr/bin/perl
#
# Simple script that demonstrates the uses of Curses::Forms
#
# $Id: test.pl,v 0.2 2000/02/29 08:47:42 corliss Exp $
#

use strict;
use Curses;
use Curses::Widgets;
use Curses::Forms;

#####################################################################
#
# Set up the environment
#
#####################################################################

my $mwh = init_scr();
my $message;

#####################################################################
#
# Program Logic starts here
#
#####################################################################

setup_scr();

$mwh->touchwin;
$mwh->refresh;

$message = << "__EOF__";
Welcome to the Curses::Forms Test Script!

This script will test various forms and data-transfer features
between widget types.  If you encounter any bugs during this
test, please e-mail me with a description of the problem, and 
the STDERR output, if any was generated.

__EOF__

msg_box( 'title'	=> " Welcome ",
		 'message'	=> $message,
		 'border'	=> 'blue',
		 'function'	=> \&clock);

cal_frm();

$message = << "__EOF__";
And this concludes our test.  Again, if any bugs presented itself
during the testing, please report them to me, Arthur Corliss, at 
corliss\@odinicfoundation.org.

Thank you.

__EOF__

msg_box( 'title'	=> " Goodbye ",
		 'message'	=> $message,
		 'border'	=> 'blue',
		 'function'	=> \&clock);

endwin() if ($mwh);

exit 0;

#####################################################################
#
# Subroutines follow here
#
#####################################################################

sub setup_scr {
	# Prints the default screen dressing
	#
	# Usage:  setup_scr()
	my $disp;

	# Display title bar and status bar at the bottom
	$disp = " Curses::Forms Test Script v0.2";
	$disp .= (' ' x ($COLS - length ($disp) - 25)) . scalar (localtime) .
		' ';
	$mwh->standout;
	$mwh->addstr(0, 0, $disp);
	$disp = ' ' x $COLS;
	$mwh->addstr($LINES - 1, 0, $disp);
	$mwh->standend;
	$mwh->refresh;
}

sub clock {
	# Update the clock in the upper right hand corner of the screen
	#
	# Usage:  clock()

	$mwh->standout();
	$mwh->addstr(0, ($COLS - 25), scalar (localtime) . ' ');
	$mwh->standend();
	$mwh->refresh();
}

sub status {
	# Prints a message out on the status bar on the bottom of the screen,
	# Prefixes the message with 'ERROR: ' if the first argument is false.
	#
	# Usage:  status(1, "this is a message");
	my $rpt = shift;
	my $disp = shift;

	$disp = "ERROR: $disp" if (! $rpt);
	$disp = substr($disp, 0, $COLS) if (length($disp) > $COLS - 7);
	$disp .= (' ' x ($COLS - length($disp)));
	$mwh->standout;
	$mwh->addstr($LINES - 1, 0, $disp);
	$mwh->standend;
	$mwh->touchwin;
	$mwh->refresh;
}

sub cal_frm {

	my @date;
	my @events = (qw( 2//2000 2//2000 29//2000 29//2000 29//2000 ));
	my @event_title = ( "07:00-My birthday", 
		"18:00-No party for me.  :-P",
		"09:00-Curses::Forms goes into Alpha",
		"11:00-Everyone begins testing Curses::Forms",
		"13:00-Everyone begins submitting bug reports");
	my @event_data = ( "I wasn't hatched--I was spawned!",
		"If it was my party, I'd cry if I wanted to. . .",
		"And the world was silent. . .",
		"I'm not responsible for the smoke. . . ;-)",
		"It's a *feature*, not a bug!");
	my @tmp;

	# Prep calendar data to always be displayed in the current month
	foreach (@events) {
		@tmp = split(/\//, $_);
		$tmp[1] = (localtime)[4] + 1;
		$_ = join("/", @tmp);
	}

	# Define the key bindings functions:

	# This function will be bound to the calendar, on [ \n], and will
	# display the selected day's events, if any, in the Events list box
	local *day_events = sub {
		my $key = shift;
		my $cal_ref = shift;
		my $list_ref = shift;
		my $date = join("/", @{$$cal_ref{'date_disp'}});
		my (%list, $i);

		for ($i = 0; $i < scalar @events; $i++) {
			$list{$i} = $event_title[$i] if ($date eq $events[$i]);
		}
		$$list_ref{'list'} = { %list };
		delete $$list_ref{'selected'} if (scalar keys %list == 0);
	};

	# Bound to the list box, on [ \n], and will retrieve the event data 
	# associated with the list entry, and print it to the Event Record 
	# text field widget
	local *event_record = sub {
		my $key = shift;
		my $list_ref = shift;
		my $txt_ref = shift;
		my $text;

		if (exists $$list_ref{'list'}{$$list_ref{'selected'}}) {
			$text = "Appt:  $event_title[$$list_ref{'selected'}]\n" .
				"Description:\n$event_data[$$list_ref{'selected'}]\n";
		} else {
			$text = "(no record selected)\n";
		}

		$$txt_ref{'content'} = $text;
	};

	# Bound to the list box, on [dD], and will delete the event listed
	local *del_event = sub {
		my $key = shift;
		my $list_ref = shift;
		my $cal_ref = shift;

		if (msg_box('title' => " Confirm Delete ", 
			'message' => "Are you sure you wish to delete this?",
			'function' => \&clock,
			'mode' => 2)) {
			splice(@events, $$list_ref{'selected'}, 1);
			splice(@event_title, $$list_ref{'selected'}, 1);
			splice(@event_data, $$list_ref{'selected'}, 1);
			day_events('', $cal_ref, $list_ref);
			delete $$list_ref{'selected'};
		}
	};

	# Bound to the calendar and list box, on [aA], and will add an event
	# to the calendar
	local *add_rec = sub {
		my $key = shift;
		my $in_ref = shift;
		my $out_ref = shift;
		my ($date, $id, $hsh_ref);
		my ($cal_ref, $list_ref);

		if ($$in_ref{'type'} eq 'calendar') {
			$date = join('/', @{$$in_ref{'date_disp'}}[1,0,2]);
			$id = join('/', @{$$in_ref{'date_disp'}});
			($cal_ref, $list_ref) = ($in_ref, $out_ref);
		} else {
			$date = join('/', @{$$out_ref{'date_disp'}}[1,0,2]);
			$id = join('/', @{$$out_ref{'date_disp'}});
			($cal_ref, $list_ref) = ($out_ref, $in_ref);
		}

		$hsh_ref = add_event($date);
		if ($hsh_ref) {
			push(@events, $id);
			push(@event_title, $$hsh_ref{'title'});
			push(@event_data, $$hsh_ref{'description'});
			day_events('', $cal_ref, $list_ref);
		}
	};

	# Create the new form object
	my $test = Curses::Forms->new({ Y => 1, X => 0,
		LINES => $LINES - 2, COLS => $COLS});

	# Adds a set of widgets to the form (each widget's settings are
	# stored in a separate anonymous hash, with two extra key/value
	# pairs of 'type' and 'name').  The type is the type of widget
	# as defined by the function calls in Curses::Widgets, and name
	# will be the english name used to refer to the widget on the form.
	$test->add({ 'type' => 'calendar', 'name' => 'cal',
		'ypos' => 0, 'xpos' => 0, 'date_disp' => \@date,
		'events' => \@events},
		{ 'type' => 'list_box', 'name' => 'events',
		'ypos' => 0, 'xpos' => 25, 'cols' => ($COLS - 27),
		'lines' => 8, 'title' => ' Events ', 'list' => [] },
		{ 'type' => 'txt_field', 'name' => 'record',
		'ypos' => 10, 'xpos' => 0, 'cols' => $COLS - 2,
		'lines' => $LINES - 14, 'title' => ' Event Record ', 
		'content' => '(no record selected)' });

	# Defines the tab order for the widgets.  Any widget that is not
	# listed in this array will not get focus (useful for text boxs
	# and the like that you want to fill with messages generated by
	# other widgets).
	$test->tab_order(qw( cal events ));

	# Binds functions and actions to specific keys used on widgets.
	# You'll always need to define at least one, which will allow you
	# to exit an interactive form.  Each binding instruction is stored
	# in an anonymous array, in the following order:  widget bound to, 
	# key, action, function, and target widget.  The latter two are
	# optional for actions to which they don't apply.
	$test->bind(["cal", "[ \n]", "Mod_Oth", \&day_events, "events"],
		["cal", "[qQ]", "Quit_Form"],
		["events", "[ \n]", "Mod_Oth", \&event_record, "record"],
		["events", "[dD]", "Mod_Oth", \&del_event, "cal"],
		["cal", "[aA]", "Mod_Oth", \&add_rec, "events"],
		["events", "[aA]", "Mod_Oth", \&add_rec, "cal"],
		["events", "[qQ]", "Quit_Form"]);

	# Sets a default, in this case, only the background function default
	$test->set_defaults( DEF_FUNC => \&clock );

	# Passing any true value when calling the activate function
	# will cause the form to be displayed, but will exit immediately,
	# and not interact with the user.
	$test->activate(1);

	# Just popping up a quick message
	$message = << "__EOF__";
This form mimics a simple scheduling application.  Use the TAB key
to move from the calendar to the list box, and use the SPACE or ENTER
key on the calendar to display the events for the day (hint:  the days
with events are highlighted or red).

Use 'd' in the list box to delete events, and 'a' in either the calendar
or the list box to add events.

Press 'q' in either the calendar or the list box to exit.

__EOF__
	msg_box( "title" => "Step 1",
		 'message'	=> $message,
		 'border'	=> 'blue',
		 'function'	=> \&clock);

	# Calling activate with no parameters (or a false value) will
	# cause the form to be displayed interactively.  It will not
	# exit until one of your bound functions calls for it to exit.
	$test->activate;

}

sub add_event {
	my $date = shift;
	my ($form, $wdgt_ref);

	# Create the form
	$form = Curses::Forms->new({ 'Y' => 3, 'X' => 5,
		'LINES' => 14, 'COLS' => 40 });

	# Add the widgets
	$form->add({ 'type' => 'txt_field', 'name' => 'date',
		'ypos' => 1, 'xpos' => 27, 'lines' => 1, 'cols' => 10,
		'title' => ' Date ', 'content' => $date },
		{ 'type' => 'txt_field', 'name' => 'title',
		'ypos' => 4, 'xpos' => 1, 'lines' => 1, 'cols' => 36,
		'title' => ' Appt ', 'l_limit' => 1,
		'c_limit' => 36, 'content' => 'New Event'},
		{ 'type' => 'txt_field', 'name' => 'description',
		'ypos' => 7, 'xpos' => 1, 'lines' => 3, 'cols' => 36,
		'title' => ' Description '},
		{ 'type' => 'buttons', 'name' => 'cmd',
		'ypos' => 12, 'xpos' => 10,
		'buttons' => ['< Add >', '< Cancel >']});

	# Set the tab order
	$form->tab_order(qw( title description cmd ));

	# Set the key bindings
	$form->bind(["cmd", "[ \n]", "Quit_Form"]);
	# Set the form defaults
	$form->set_defaults( DEF_FUNC => \&clock, BORDER => 1,
		BORDER_COLOUR => 'blue', TITLE => ' Add Event ');

	# Activate the form
	$wdgt_ref = $form->activate;

	# Test to see if 'Add' or 'Cancel' buttons were pushed
	if ($$wdgt_ref{'cmd'}{'active_button'} == 0) {
		msg_box('title' => " Alert ", 'message' => 'Event Added!');
		return { 'title' => $$wdgt_ref{'title'}{'content'},
			'description' => $$wdgt_ref{'description'}{'content'} };
	} else {
		msg_box('title' => " Alert ", 'message' => 'Add Canceled!');
		return 0;
	}
}
