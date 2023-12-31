package Spork;


our $limit = 4;
our $running = 0 ;
#our @pids;


sub setup {
    ($Spork::limit) = @_;

};


sub do_spork {
my @errors;
    my ($code,@args) = @_;
    while ($running >= (@errors?1: $limit) ) {
	my $rv = wait;
	if ($rv > 0 ) {
	    if ($? > 0 ) {
		push @errors, "Child: $rv returned $?";
	    };
	};
	$running--;
    };

if (@errors) {die join("\n",@errors);}

	

    my $cpid = fork();
    if ($cpid == 0 ) {
	if (defined $main::dbh) {
##	    print STDERR "DBH InactiveDestroy set\n";
	$main::dbh->{InactiveDestroy} = 1;   
	};
# line 23
# child
	exit(&$code(@args));
    };
    if ($cpid > 0 ) {
	#push @pids,$cpid;
	$running++;
    };
    if ($cpid < 0 ) {
	die "Fork failed: $!";
    };
    return(0);
};

sub do_wait {
my @errors;
    while ($running > 0 ) {
	my $rv = wait;
	if ($rv > 0 ) {
	    if ($? > 0 ) {
		push @errors, "Child: $rv returned $?";
	    };
	};
	$running--;
    };
if (@errors) {die join("\n",@errors);}
    return(0);
};


1;
