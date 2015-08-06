use utf8;
package Kinza::Schema::Result::AllowedCourseYear;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kinza::Schema::Result::AllowedCourseYear

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::TimeStamp>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "TimeStamp");

=head1 TABLE: C<allowed_course_year>

=cut

__PACKAGE__->table("allowed_course_year");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 course_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 year_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "course_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "year_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 course

Type: belongs_to

Related object: L<Kinza::Schema::Result::Course>

=cut

__PACKAGE__->belongs_to(
  "course",
  "Kinza::Schema::Result::Course",
  { id => "course_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 year

Type: belongs_to

Related object: L<Kinza::Schema::Result::Year>

=cut

__PACKAGE__->belongs_to(
  "year",
  "Kinza::Schema::Result::Year",
  { id => "year_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-08-06 20:26:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8U6iIOKDFv04KikFi42j3Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
