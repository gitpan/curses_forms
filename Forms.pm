########################################################################
#
# Curses Forms Module
#
# $Id: Forms.pm,v 0.2 2000/02/29 08:46:39 corliss Exp $
#
# (c) Arthur Corliss, 2000
#
# Requires the Curses module for perl, (n)Curses libraries, and the
# Curses::Widgets Module
#
########################################################################

package Curses::Forms;

use strict;
use vars qw( $VERSION );
use Curses;
use Curses::Widgets 1.1;

$VERSION = '.2';

########################################################################
#
# Module code follows. . .
#
########################################################################

{
	# Private Class attribute for tracking active window handles
	my @forms = ();

	# Add a window handle for an active form
	sub _add_handle {
		push(@forms, shift);
	}

	# Remove a window handle
	sub _del_handle {
		pop(@forms);
	}

	sub refresh_forms {
		# Refresh all open handles
		foreach (@forms) { $_->touchwin; $_->refresh };
	}
}

sub new {
	# New class constructor
	#
	# Usage:  $frm = Curses::Forms->new({ key => value, ....});

	my $class = shift;
	my $self = {};

	bless $self, $class;

	$self->_conf(shift);

	return $self;
}

sub _conf {
	# Configures the base attributes of the form,
	#
	# Internal use only.

	my $self = shift;
	my $conf_ref = shift;
	my @opts = qw( Y X LINES COLS );

	# Process the configuration directives
	foreach (keys %$conf_ref) {
		if ($_ =~ /^(Y|X|LINES|COLS)$/) {
			$self->{$_} = $$conf_ref{$_};
		} else {
			warn "Unknown parameter: $_\n";
		}
	}

	# Check to see that all minimum parameters were defined
	foreach (@opts) {
		unless (exists $self->{$_}) {
			warn "$_ not defined\n";
		}
	}

	# Define pre-defaults
	$self->{DEF_ACTV} = 'green';
	$self->{DEF_INACTV} = 'red';
	$self->{DEF_TAB} = "\t";
	$self->{DEF_FUNC} = '';

	# Initialise the Widget/Bind hash and Order array
	$self->{WIDGETS} = {};
	$self->{BIND} = {};
	$self->{ORDER} = [];
	$self->{BORDER} = 0;
	$self->{TITLE} = '';
}

sub _preflight {
	# Do some error checking and set the DISABLE flag if necessary
	#
	# Internal use only.

	my $self = shift;
	my @opts = qw( Y X LINES COLS );

	if (($self->{X} + $self->{COLS} > $COLS) || 
		($self->{Y} + $self->{LINES} > $LINES)) {
		warn "Form's boundaries would extend past the console's" .
			"--disabling\n";
		$self->{DISABLED} = 1;
	} else {
		$self->{DISABLED} = 0;
	}
	foreach (@opts) {
		unless (exists $self->{$_}) {
			warn "$_ not defined.\n";
			$self->{DISABLED} = 1;
		}
	}
}

sub add {
	# Add a series of widgets to the form object.  Each widget's data
	# is passed in an anonymous hash.
	#
	# Usage:  $frm->add({ [widget data. . .] }, {[etc. . .]});

	my $self = shift;
	my $wdgt_ref;
	my @widgets = (qw( txt_field list_box buttons calendar ));

	while ($wdgt_ref = shift) {
		unless (exists $$wdgt_ref{'name'}) {
			warn "Widget passed without a name--not adding.\n";
			next;
		}
		if (exists ${$self->{WIDGETS}}{$$wdgt_ref{'name'}}) {
			warn "Widget $$wdgt_ref{'name'} already defined--" .
				"overwriting old definition.\n"
		}
		unless (grep /^$$wdgt_ref{'type'}$/, @widgets) {
			warn "Widget type $$wdgt_ref{'type'} unknown--not adding.\n";
			next;
		}
		${$self->{WIDGETS}}{$$wdgt_ref{'name'}} = $wdgt_ref;
	}
}

sub bind {
	# Add a series of key bindings to the widget specified.
	#
	# Usage:  $frm->bind([widget, regex, action, func, widget], etc. . .);

	my $self = shift;
	my ($bind, $widget);

	while ($bind = shift) {
		$widget = shift @$bind;
		if (exists ${$self->{WIDGETS}}{$widget}) {
			unless (exists ${$self->{BIND}}{$widget}) {
				${$self->{BIND}}{$widget} = [];
			}
			push (@{${$self->{BIND}}{$widget}}, $bind);
		} else {
			warn "Attempting to bind keys to nonexistent widget: $_\n";
		}
	}
}

sub tab_order {
	# Specify the active widget tab order.
	#
	# Usage:  $frm->tab_order(qw( field1 field2 cal1 ));

	my $self = shift;
	my $wdgt;

	$self->{ORDER} = [];
	while ($wdgt = shift) {
		if (exists ${$self->{WIDGETS}}{$wdgt}) {
			push(@{$self->{ORDER}}, $wdgt);
		} else {
			warn "Non-existent widget in order array: $wdgt\n";
		}
	}
}

sub set_defaults {
	# Specify form-wide defaults.
	#
	# Usage:  $frm->set_defaults( DEF_FUNC => \&some_func );

	my $self = shift;
	my %defs = @_;
	my @valid = qw( DEF_FUNC DEF_TAB DEF_ACTV DEF_INACTV BORDER TITLE
		BORDER_COLOUR );

	foreach (keys %defs) {
		unless (grep /^$_$/, @valid) {
			warn "Unknown option:  $_\n";
			next;
		}
		$self->{$_} = $defs{$_};
	}
}

sub activate {
	# Activates the form.  Returns a hash ref of widget names and
	# values upon exiting.  Will only draw the form and immediately
	# exit if any true value is passed as a parameter.
	#
	# Usage:  $result_ref = $frm->activate;

	my $self = shift;
	my $draw_only = shift || 0;
	my @order = @{$self->{ORDER}};
	my $widget = 0;
	my ($fwh, $wdgt_ref, %opts, $pos);
	my ($key, $content, $tmp, $actn);

	# Do preflight checks
	$self->_preflight;
	return if ($self->{DISABLED});

	# Create the window and add it to the active forms array
	$fwh = newwin($self->{LINES}, $self->{COLS}, $self->{Y}, $self->{X});
	_add_handle($fwh);

	# Draw the form (all widgets rendered inactive)
	if ($self->{BORDER}) {
		select_colour($fwh, $self->{'BORDER_COLOUR'}) if
			($self->{'BORDER_COLOUR'});
		$fwh->box(ACS_VLINE, ACS_HLINE);
		$fwh->attrset(0);
	}
	if ($self->{TITLE} ne '') {
		$self->{TITLE} = substr($self->{TITLE}, 0, $self->{COLS} - 2)
			if (length($self->{TITLE}) > $self->{COLS} - 2);
		$fwh->standout;
		$fwh->addstr(0, 1, $self->{TITLE});
		$fwh->standend;
	}
	foreach (keys %{$self->{WIDGETS}}) {
		$wdgt_ref = ${$self->{WIDGETS}}{$_};
		$self->_draw_wdgt($fwh, $wdgt_ref);
	}

	# Take an early exit if a draw only request was made
	if ($draw_only) {
		$fwh->delwin;
		return;
	}

	# Set some defaults and start the interaction
	%opts = ('border' => $self->{DEF_ACTV});
	$opts{'function'} = $self->{ DEF_FUNC } if ($self->{ DEF_FUNC });
	$actn = 1;
	while ($actn ne "exit") {
		$fwh->refresh;

		# Grab a reference to the current widget
		$wdgt_ref = ${$self->{WIDGETS}}{$order[$widget]};

		# Process according to type
		if ($$wdgt_ref{'type'} eq "txt_field") {
			($key, $content, $pos) = txt_field( 'window'		=> $fwh,
				%opts, %$wdgt_ref);
			$$wdgt_ref{'content'} = $content;
			$$wdgt_ref{'pos'} = $pos;
			$actn = $self->_proc_keys($wdgt_ref, $fwh, $key);

		} elsif ($$wdgt_ref{'type'} eq "buttons") {
			($key, $content) = buttons( 'window'		=> $fwh,
				%opts, %$wdgt_ref);
			$$wdgt_ref{'active_button'} = $content;
			$actn = $self->_proc_keys($wdgt_ref, $fwh, $key);

		} elsif ($$wdgt_ref{'type'} eq "list_box") {
			($key, $content) = list_box( 'window'		=> $fwh,
				%opts, %$wdgt_ref);
			$$wdgt_ref{'selected'} = $content;
			$actn = $self->_proc_keys($wdgt_ref, $fwh, $key);

		} elsif ($$wdgt_ref{'type'} eq "calendar") {
			$key = calendar( 'window'		=> $fwh,
				%opts, %$wdgt_ref);
			$actn = $self->_proc_keys($wdgt_ref, $fwh, $key);

		} else {
			warn "Unknown widget type:  $$wdgt_ref{'type'}\n";
		}

		# Advance to next widget if needed
		if ($actn eq "tab") {
			$self->_draw_wdgt($fwh, $wdgt_ref);
			++$widget;
			$widget = 0 if (scalar @order <= $widget);
		}
		$self->_draw_wdgt($fwh, $wdgt_ref) if ($actn =~ /^(exit|tab)$/);
	}

	# Remove from the active window array and destroy window
	_del_handle();
	$fwh->delwin;

	# Return all the widget values
	return { %{$self->{WIDGETS}} };
}

sub _proc_keys {
	# Processes any key bindings for the widget specified
	#
	# Internal use only.

	my $self = shift;
	my $wdgt_ref = shift;
	my $fwh = shift;
	my $key = shift;
	my $bnd_ref = ${$self->{BIND}}{$$wdgt_ref{'name'}} || [];
	my $nxt = $self->{DEF_TAB};
	my ($out_ref, $actn, $rtrn);

	# Check for each matching binding for the widget
	foreach (@$bnd_ref) {
		if ($key =~ /^$$_[0]$/) {

			# Process by action
			if ($$_[1] eq "Quit_Form") {
				$actn = "exit";

			} elsif ($$_[1] eq "Nxt_Wdgt") {
				$actn = "tab";

			} elsif ($$_[1] =~ /^Mod_(Own|Oth)$/) {
				if ($1 eq "Own") {
					$out_ref = $wdgt_ref;
				} else {
					$out_ref = ${$self->{WIDGETS}}{$$_[3]};
				}
				$rtrn = &{$$_[2]}($key, $wdgt_ref, $out_ref);
				$self->_draw_wdgt($fwh, $out_ref);
				if (defined $rtrn  && $rtrn eq "Quit_Form") {
					$actn = "exit";
				} else {
					$actn = "cont";
				}
			}
		}
	}
	$actn = "tab" if (! $actn && $key =~ /^$nxt$/);

	return $actn || 'cont';
}

sub _draw_wdgt {
	# Draws the specified widget in inactive mode.
	#
	# Internal use only.

	my $self = shift;
	my $fwh = shift;
	my $wdgt_ref = shift;
	my $function = $$wdgt_ref{'type'};

	no strict 'refs';

	&$function( 'window'=> $fwh,
		   %$wdgt_ref,
		   'draw_only'	=> 1,
		   'border'		=> $self->{DEF_INACTV});
}

1;
