use utf8;
package Kinza::Schema::Result::Year;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kinza::Schema::Result::Year

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

=head1 TABLE: C<year>

=cut

__PACKAGE__->table("year");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 seq

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "seq",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 allowed_course_years

Type: has_many

Related object: L<Kinza::Schema::Result::AllowedCourseYear>

=cut

__PACKAGE__->has_many(
  "allowed_course_years",
  "Kinza::Schema::Result::AllowedCourseYear",
  { "foreign.year_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 forms

Type: has_many

Related object: L<Kinza::Schema::Result::Form>

=cut

__PACKAGE__->has_many(
  "forms",
  "Kinza::Schema::Result::Form",
  { "foreign.year_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-09-06 12:52:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cPiWh4/c7g5f4JaSmlGc6g

__PACKAGE__->many_to_many(
  'allowed_courses',
  'allowed_course_years',
  'course',
);

sub get_allowed_courses {
  my $self = shift;

  return $self->allowed_courses({}, {
    prefetch => { presentations => 'term' },
    join => {presentations => 'attendances' },
    '+select' => { count =>  'attendances.id' },
    '+as' => [ 'att_count' ],
    group_by => [ 'course.id', 'presentations.id' ],
  });
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
