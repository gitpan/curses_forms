use ExtUtils::MakeMaker;

%mods = ( 'Curses'	=> '0',
	'Curses::Widgets' => '1.1' );

WriteMakefile(
    'NAME'	=> 'Curses::Forms',
	'AUTHOR' => 'Arthur Corliss <corliss@odinicfoundation.org>',
	'ABSTRACT' => 
	'Complement to Curses::Widgets for high level access to form design.',
    'VERSION' => '0.2',
	'PREREQ_PM'	=> \%mods
);
