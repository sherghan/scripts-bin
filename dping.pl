#!/usr/bin/perl -W
use strict;

# ####### config ####### #
my $sound = '/usr/share/sounds/freedesktop/stereo/message.oga';
my $lineMark = 25;
my $ping = '/bin/ping';
my $date = '/bin/date';
my $ping_pid = 0;
my $play;

# ####### SUBS ####### #
sub printStampPrefix() {
    my ($S, $M, $H) = localtime(time);
    printf "\r%02d:%02d.%02d ",$H,$M,$S;
}
sub tskkill() {
    if ( $ping_pid != 0 ) {
      system "kill -ALRM $ping_pid";
    }
}

# ####### setup ####### #
if ( $ARGV[0] =~ /-s/ && $ARGV[1] !~ /\d+/ ){
    shift;
    undef $play;
    print "[>] Silence mode\n";

} else {
    print "[i] Use '-s' for silent mode\n";

    if ( ! -e $sound ){
        die "[!] Can't find the sound file! ($sound): $!\n";
    }

    $play = `which ogg123 2>/dev/null`;
    if ( $? == 0 ){
        chomp($play);
        $play = $play.' --quiet ';

    } else {
        die "[!] Can't find a sound player!\n";
    }
}

# ####### ping Wrapper ####### #
$ping_pid = open(NET, "$ping @ARGV |") || die "[!] Cannot fork! $!\n";
my ($lineCounter, $expected, $ttl) = (0, 1, 0);

$SIG{INT} = \&tskkill;  # CATCH: CTRL-C
while (<NET>) {
    printStampPrefix();
    if ( $_ =~ /\d+ bytes from .* (icmp_\w+=(\d+) ttl=(\d+) time\=\S+ .*)/ ){
        my $line = $1;
        my $note = '';

#         == Expected check ==
        # $note .= " \t[DBG seq: got=$2 exp=$expected]"; # DEBUG
        my $got = $2;
        if ( $got > $expected ){
            my $missed = $got-$expected;
            my $plural = '';
            $plural = 's' if $missed > 1;
            $note .= "\t-- ".$missed." packet${plural} MISSED --";
            $expected = $got+1;
        }

        elsif ( $got == $expected ){ # Everything is OK - packet came in sequence
            $expected++;
        }

#       elsif ( $got == ($expected -1) ){ $note .= "\t-- DUP --"; }

        elsif ( $got < ($expected -1) ) {
            $note .= "\t-- Late-comer packet (".($got-$expected).") --";
        }

#         == TTL check ==
        if ( $ttl != $3 ) {
            $note .= "\t-- TTL CHANGE --" if $ttl;
            $ttl = $3;
        }

#         == Display ==
        my $icmp_req = sprintf("%-4d",$got);
        $line =~ s/(icmp_\w+=)\d+/$1$icmp_req/;
        printf "   %s%s\n",$line,$note;
        system "$play $sound &" if $play;

    } else {
        print
    }

    if ( $lineCounter >= $lineMark ){
        print "\r[i]  -- $lineMark mark --\n";
        $lineCounter=0;
    }
    $lineCounter++;
}
close(NET) || print "RET: $?\n";

exit $?;

#EOF
