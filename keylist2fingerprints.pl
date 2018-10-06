#!/usr/bin/perl 
use strict;
use warnings;

# expects STDIN to be output from 'gpg --list-keys --with-colons --fingerprint'
#
my $email;
my $fingerprint;

while( <> ) {
    if (/^fpr/) {
        my @parts = split(/:/, $_);
        $fingerprint = $parts[9];
    }
    if (/^uid/) {
        my @parts = split(/:/, $_);
        $email = $parts[9];
        $email =~ s/.*<(.*)>.*/$1/;    # if we see <>, take only contents
        print "$email $fingerprint\n";
    }
}

__END__

# expects STDIN to be output from 'gpg --list-keys --with-colons --fingerprint'
# so, expects input like this:
tru::1:1537794548:1563123204:3:1:5
pub:u:2048:1:330F3E0D33CF057D:1523910937:::u:::scESC:
fpr:::::::::5C43BCCB38AC6A237DB7D912330F3E0D33CF057D:
uid:u::::1523910937::517CC80136A9BEF0461CCCB171FB4172AAC4C164::joshr <joshr@xl18.joshr.com>:
sub:u:2048:1:1F01740FDF1C369F:1523910937::::::e:
pub:-:2048:1:D488D90470D2D686:1523987921:::-:::scESC:
fpr:::::::::4756C771077284DA88191B33D488D90470D2D686:
uid:-::::1523987921::6656D9E7719DCC23EEC9C05BC34AFE0FEC36DE11::joshr <joshr@lesliesmacbookair.joshr.com>:
sub:-:2048:1:E37D70E566728443:1523987921::::::e:
pub:u:2048:1:E9E821BDE0E58FD3:1531587204:1563123204::u:::scESC:
fpr:::::::::999E6B34384A6237D6C43991E9E821BDE0E58FD3:
uid:u::::1531587204::644482AFE0EFE20116C257A175BF13B9036766C3::joshr <joshr@test.xl18.joshr.com>:
sub:u:2048:1:236B35663005D962:1531587204:1563123204:::::e:
pub:e:2048:1:E6D4C84CDF81C425:1537658276:1537745045::u:::sc:
fpr:::::::::E515A4912B8AB470156F397BE6D4C84CDF81C425:
uid:e::::1537658645::49AC77863E14A3DA850264ED3DDDBEF8BCF35DD2::user4 <user4@gitsecret.io>:
sub:e:2048:1:A4C027432E00D79C:1537658276::::::e:

# and creates output like this:
% gpg --list-keys --with-colons --fingerprint | ./keylist2finderprints.pl
joshr@xl18.joshr.com 5C43BCCB38AC6A237DB7D912330F3E0D33CF057D
joshr@lesliesmacbookair.joshr.com 4756C771077284DA88191B33D488D90470D2D686
joshr@test.xl18.joshr.com 999E6B34384A6237D6C43991E9E821BDE0E58FD3
user4@gitsecret.io E515A4912B8AB470156F397BE6D4C84CDF81C425
