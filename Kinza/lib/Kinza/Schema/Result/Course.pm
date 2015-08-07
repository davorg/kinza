use utf8;
package Kinza::Schema::Result::Course;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kinza::Schema::Result::Course

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

=head1 TABLE: C<course>

=cut

__PACKAGE__->table("course");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 title

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 teacher

  data_type: 'varchar'
  default_value: 'Mrs. Teacher'
  is_nullable: 0
  size: 255

=head2 room

  data_type: 'varchar'
  default_value: 'Room 101'
  is_nullable: 0
  size: 255

=head2 capacity

  data_type: 'integer'
  default_value: 27
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "title",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "teacher",
  {
    data_type => "varchar",
    default_value => "Mrs. Teacher",
    is_nullable => 0,
    size => 255,
  },
  "room",
  {
    data_type => "varchar",
    default_value => "Room 101",
    is_nullable => 0,
    size => 255,
  },
  "capacity",
  { data_type => "integer", default_value => 27, is_nullable => 0 },
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
  { "foreign.course_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 presentations

Type: has_many

Related object: L<Kinza::Schema::Result::Presentation>

=cut

__PACKAGE__->has_many(
  "presentations",
  "Kinza::Schema::Result::Presentation",
  { "foreign.course_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-08-06 21:20:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:OZOk6Ub4lvYIpB6HmsKX+w

__PACKAGE__->many_to_many(
  'allowed_years',
  'allowed_course_years',
  'year',
);

__PACKAGE__->many_to_many(
  'terms',
  'presentation',
  'term',
);

sub in_term {
  my $self = shift;
  my ($term_id) = @_;

  return $self->presentations->find({
    term_id => $term_id,
  });
}


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
