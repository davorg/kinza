use utf8;
package Kinza::Schema::Result::Presentation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kinza::Schema::Result::Presentation

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

=head1 TABLE: C<presentation>

=cut

__PACKAGE__->table("presentation");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 course_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 term_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 number_of_terms

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "course_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "term_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "number_of_terms",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 attendances

Type: has_many

Related object: L<Kinza::Schema::Result::Attendance>

=cut

__PACKAGE__->has_many(
  "attendances",
  "Kinza::Schema::Result::Attendance",
  { "foreign.presentation_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

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

=head2 term

Type: belongs_to

Related object: L<Kinza::Schema::Result::Term>

=cut

__PACKAGE__->belongs_to(
  "term",
  "Kinza::Schema::Result::Term",
  { id => "term_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-08-06 21:20:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:YTuKcLoRM8o+QdjfN8Lqmw

__PACKAGE__->many_to_many(
  'students',
  'attendance',
  'student',
);

sub spaces {
  my $self = shift;

  return $self->course->capacity - $self->attendances->count;
}

sub available {
  my $self = shift;

  return $self->spaces > 0;
}

sub full {
  my $self = shift;

  return ! $self->available;
}


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
