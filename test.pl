#!/usr/bin/perl -w
#
# Simple script that demonstrates the uses of Curses::Forms
#
# $Id: test.pl,v 0.1 2000/02/12 11:57:03 corliss Exp corliss $
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

my $mwh = new Curses;
my $message;

#####################################################################
#
# Program Logic starts here
#
#####################################################################

init_scr();

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

tst_frm();

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

sub init_scr {
	# Check to see if executed from an interactive terminal,
	# and input/output not redirected, and setup initial screen
	# if everything passes.
	#
	# Usage:  check_tty()
	my $disp;

	if (-t STDIN && -t STDOUT) {
	
		# Check for minimum allowable terminal size
		$mwh = new Curses;
		if ($COLS < 80 || $LINES < 24) {
			endwin();
			print "\nYour terminal size isn't large enough!\n\n";
			exit 1;
		}
	} else {
		print "\nThe terminal isn't interactive!\n\n";
		exit 1;
	}

	# Initialise console settings
	noecho();
	cbreak();
	halfdelay(10);
	$mwh->keypad(1);

	# Display title bar and status bar at the bottom
	$disp = " Curses::Forms Test Script v0.1";
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

sub tst_frm {

	my @date;

	# Create the new form object
	my $test = Curses::Forms->new({ 'Y' => 1, 'X' => 0,
		'LINES' => $LINES - 2, 'COLS' => $COLS});

	# Assigns the default function to call in the background
	# while waiting on input
	$test->{DEF_FUNC} = \&clock;

	# Adds a set of widgets to the form (each widget's settings are
	# stored in a separate anonymous hash, with two extra key/value
	# pairs of 'type' and 'name').  The type is the type of widget
	# as defined by the function calls in Curses::Widgets, and name
	# will be the english name used to refer to the widget on the form.
	$test->add({ 'type' => 'calendar', 'name' => 'cal1',
		'ypos' => 0, 'xpos' => 0, 'date_disp' => \@date },
		{ 'type' => 'txt_field', 'name' => 'field1',
		'ypos' => 0, 'xpos' => 25, 'cols' => ($COLS - 27),
		'title' => 'Date', 'content' => '(no date entered)',
		'l_limit' => 1, 'regex' => "\n\ta-zA-Z"});

	# Defines the tab order for the widgets.  Any widget that is not
	# listed in this array will not get focus (useful for text boxs
	# and the like that you want to fill with messages generated by
	# other widgets).
	$test->{ORDER} = [ qw( cal1 field1 )];

	# Binds functions and actions to specific keys used on widgets.
	# You'll always need to define at least one, which will allow you
	# to exit an interactive form.  Each binding instruction is stored
	# in an anonymous array, in the following order:  widget bound to, 
	# key, action, function, and target widget.  The latter two are
	# optional for actions to which they don't apply.
	$test->bind( [ "cal1", "[qQ]", "Quit_Form" ],
		[ "cal1", "[ \n]", "Mod_Oth", \&date2txt, "field1" ],
		[ "field1", "\n", "Mod_Oth", \&txt2date, "cal1" ]);

	# Passing any true value when calling the activate function
	# will cause the form to be displayed, but will exit immediately,
	# and not interact with the user.
	$test->activate(1);

	# Just popping up a quick message
	$message = << "__EOF__";
This form has two widgets:  a calendar and a text field.  To demonstrate
communication and value passing between widgets, press ' ' or <ENTER> in
the calendar to fill the text field with the highlighted date.  Press 
<ENTER> in the text field after putting in a mm/dd/yyyy formatted date to
move the calendar to that date.  Use <TAB> to move between them.


Press 'q' in the calendar to exit.

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

sub date2txt {
	# Accepts the key pressed and an array reference to the date
	# stored in a calendar widget, converts it to a string, and 
	# returns it.
	#
	# Usage:  $txt = date2txt($key, \@date);

	my $key = shift;
	my $dt_ref = shift;
	my @date = @$dt_ref[1,0,2];

	return join("/", @date);
}

sub txt2date {
	# Accepts the key pressed and a string which it will attempt
	# to convert to a date stored in an array, and returns it.
	# Hey, this is a demo--there are bad dates this will accept.  ;-)
	#
	# Usage:  @date = txt2date($key, $string);

	my $key = shift;
	my $content = shift;
	my @date = ();

	if ($content =~ /^\d{1,2}[\/-]\d{1,2}[\/-]\d{4}$/) {
		@date = (split(/[-\/]/, $content))[1,0,2];
		if ($date[1] < 1 || $date[1] > 12 || $date[0] < 1 ||
			$date[0] > 31 || $date[2] < 1) {
			@date = ();
			beep();
			status(0, "Date must be valid and in the format of mm/dd/yyyy");
		}
	} else {
		beep();
		status(0, "Date format must be mm/dd/yyyy");
	}

	return @date;
}
