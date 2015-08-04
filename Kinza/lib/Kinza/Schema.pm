use utf8;
package Kinza::Schema;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use Moose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;


# Created by DBIx::Class::Schema::Loader v0.07039 @ 2014-08-28 20:02:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ylgw0XM64uPIn2FonT7uAw


# You can replace this text with custom code or comments, and it will be preserved on regeneration

sub get_schema {
  unless (defined $ENV{KZ_USER} && defined $ENV{KZ_PASS} &&
    defined $ENV{KZ_HOST}) {
    die "Must set KZ_USER, KZ_PASS and KZ_HOST\n";
  }

  my $sch = __PACKAGE__->connect(
    "dbi:mysql:database=kinza;host=$ENV{KZ_HOST}",
    $ENV{KZ_USER}, $ENV{KZ_PASS},
    { mysql_enable_utf8 => 1 },
  ) or die "Can't connect to database";

  return $sch;
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
