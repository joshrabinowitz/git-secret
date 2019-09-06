package GitSecret::Config;
use Moose;

has 'secrets_dir' => ( is => 'rw', isa => 'Str', default => sub { $ENV{SECRETS_DIR} // ".gitsecret" } );
1;
