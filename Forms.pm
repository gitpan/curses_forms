########################################################################
#
# Curses Forms Module
#
# $Id: Forms.pm,v 0.1 2000/02/12 11:53:32 corliss Exp corliss $
#
# (c) Arthur Corliss, 1998
#
# Requires the Curses module for perl, (n)Curses libraries, and the
# Curses::Widgets Module
#
########################################################################

package Curses::Forms;

use strict;
use vars qw($VERSION);
use Curses;
use Curses::Widgets;

$VERSION = '.01';

########################################################################
#
# Module code follows. . .
#
########################################################################

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
			warn "$_ not defined\n";
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

	while ($wdgt_ref = shift) {
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

sub order {
	# Specify the active widget tab order.
	#
	# Usage:  $frm->order(qw( field1 field2 cal1 ));

	my $self = shift;
	my $wdgt;

	while ($wdgt = shift) {
		if (exists ${$self->{WIDGETS}}{$_}) {
			push(@{$self->{ORDER}}, $_);
		} else {
			warn "Non-existent widget in order array: $_\n";
		}
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
	my ($fwh, $wdgt_ref, %opts);
	my ($key, $content, $tmp, $actn);

	# Do preflight checks
	$self->_preflight;
	return if ($self->{DISABLED});

	# Create the window
	$fwh = newwin($self->{LINES}, $self->{COLS}, $self->{Y}, $self->{X});

	# Draw the form (all widgets rendered inactive)
	foreach (keys %{$self->{WIDGETS}}) {
		$wdgt_ref = ${$self->{WIDGETS}}{$_};
		$self->_draw_wdgt($fwh, $wdgt_ref);
	}
	$fwh->refresh;

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

		# Grab a reference to the current widget
		$wdgt_ref = ${$self->{WIDGETS}}{$order[$widget]};

		# Process according to type
		if ($$wdgt_ref{'type'} eq "txt_field") {
			($key, $content) = txt_field( 'window'		=> $fwh,
				%opts, %$wdgt_ref);
			$$wdgt_ref{'content'} = $content;
			$actn = $self->_proc_keys($wdgt_ref, $fwh, $key, $content);

		} elsif ($$wdgt_ref{'type'} eq "buttons") {
			($key, $content) = buttons( 'window'		=> $fwh,
					 %opts, %$wdgt_ref);
			$$wdgt_ref{'active_button'} = $content;
			$actn = $self->_proc_keys($wdgt_ref, $fwh, $key, $content);

		} elsif ($$wdgt_ref{'type'} eq "list_box") {
			($key, $content) = list_box( 'window'		=> $fwh,
					 %opts, %$wdgt_ref);
			$$wdgt_ref{'selected'} = $content;
			$actn = $self->_proc_keys($wdgt_ref, $fwh, $key, $content);

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

	# Destroy window
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
	my $content = shift || '';
	my $bnd_ref = ${$self->{BIND}}{$$wdgt_ref{'name'}} || [];
	my $nxt = $self->{DEF_TAB};
	my ($out, $out2, $out_ref, $actn);

	# Check for each matching binding for the widget
	foreach (@$bnd_ref) {
		if ($key =~ /^$$_[0]$/) {

			# Process by action
			if ($$_[1] eq "Quit_Form") {
				$actn = "exit";

			} elsif ($$_[1] eq "Nxt_Wdgt") {
				$actn = "tab";

			} elsif ($$_[1] eq "Mod_Own") {

				# Select type widget
				if ($wdgt_ref->{'type'} eq 'txt_field') {
					$out = &{$$_[2]}($key, $content);
					$wdgt_ref->{'content'} = $out;

				} elsif ($wdgt_ref->{'type'} eq 'list_box') {
					($out, $out2) = 
						&{$$_[2]}($key, $content, $wdgt_ref->{'list'});
					$wdgt_ref->{'selected'} = $out;
					%{$wdgt_ref->{'list'}} = %$out2;

				} elsif ($wdgt_ref->{'type'} eq 'buttons') {
					($out, $out2) = 
						&{$$_[2]}($key, $content, $wdgt_ref->{'buttons'});
					$wdgt_ref->{'active_button'} = $out;
					@{$wdgt_ref->{'buttons'}} = @$out2;

				} elsif ($wdgt_ref->{'type'} eq 'calendar') {
					$content = $wdgt_ref->{'date_disp'};
					$out = &{$$_[2]}($key, $content);
					@{$wdgt_ref->{'date_disp'}} = @$out;

				} else {
					warn $wdgt_ref->{'type'} . " not known.\n";
				}
				$actn = "cont";

			} elsif ($$_[1] eq "Mod_Oth") {
				$out_ref = ${$self->{WIDGETS}}{$$_[3]};

				# Select type conversion
				if ($wdgt_ref->{'type'} eq 'txt_field' &&
					$out_ref->{'type'} eq 'list_box') {

					# txt_field to list_box not done yet

				} elsif ($wdgt_ref->{'type'} eq 'list_box' &&
					$out_ref->{'type'} eq 'txt_field') {
					$out = &{$$_[2]}($key, $wdgt_ref->{'selected'},
						$wdgt_ref->{'list'});
					$out_ref->{'content'} = $out;

				} elsif ($wdgt_ref->{'type'} eq 'txt_field' &&
					$out_ref->{'type'} eq 'calendar') {
					$out = [ &{$$_[2]}($key, $content) ];
					@{$out_ref->{'date_disp'}} = @$out if (scalar @$out == 3);

				} elsif ($wdgt_ref->{'type'} eq 'calendar' &&
					$out_ref->{'type'} eq 'txt_field') {
					$out = &{$$_[2]}($key, $wdgt_ref->{'date_disp'});
					$out_ref->{'content'} = $out;

				} elsif ($wdgt_ref->{'type'} eq 'txt_field' &&
					$out_ref->{'type'} eq 'txt_field') {
					$out = &{$$_[2]}($key, $content);
					$out_ref->{'content'} = $out;

				} else {
					warn $wdgt_ref->{'type'} . " to " . $out_ref->{'type'} .
						" conversions not allowed.\n";
				}
				$self->_draw_wdgt($fwh, $out_ref);
				$actn = "cont";
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

	if ($$wdgt_ref{'type'} eq "txt_field") {
		txt_field( 'window'		=> $fwh,
				   %$wdgt_ref,
				   'draw_only'	=> 1,
				   'border'		=> $self->{DEF_INACTV});
	} elsif ($$wdgt_ref{'type'} eq "buttons") {
		buttons( 'window'		=> $fwh,
				 %$wdgt_ref,
				 'draw_only'	=> 1,
				 'border'		=> $self->{DEF_INACTV});
	} elsif ($$wdgt_ref{'type'} eq "list_box") {
		list_box( 'window'		=> $fwh,
				  %$wdgt_ref,
				 'draw_only'	=> 1,
				 'border'		=> $self->{DEF_INACTV});
	} elsif ($$wdgt_ref{'type'} eq "calendar") {
		calendar( 'window'		=> $fwh,
				 %$wdgt_ref,
				 'draw_only'	=> 1,
				 'border'		=> $self->{DEF_INACTV});
	} else {
		warn "Unknown widget type:  $$wdgt_ref{'type'}\n";
	}
}

1;
