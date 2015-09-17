use utf8;
package Kinza::Schema::Result::Student;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kinza::Schema::Result::Student

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

=head1 TABLE: C<student>

=cut

__PACKAGE__->table("student");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 email

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 password

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 form_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 verify

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "email",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "password",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "form_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "verify",
  { data_type => "varchar", is_nullable => 1, size => 255 },
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
  { "foreign.student_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 form

Type: belongs_to

Related object: L<Kinza::Schema::Result::Form>

=cut

__PACKAGE__->belongs_to(
  "form",
  "Kinza::Schema::Result::Form",
  { id => "form_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 password_resets

Type: has_many

Related object: L<Kinza::Schema::Result::PasswordReset>

=cut

__PACKAGE__->has_many(
  "password_resets",
  "Kinza::Schema::Result::PasswordReset",
  { "foreign.student_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07039 @ 2014-09-08 21:57:00
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WItYpQSEGRBD4mS7LjkZWQ

__PACKAGE__->many_to_many(
  'presentations',
  'attendences',
  'presentation',
);

sub sorted_attendances {
  my $self = shift;

  return $self->attendances->search({}, {
    join => { presentation => 'term' },
    order_by => 'term.seq',
  });
}

sub choices {
  my $self = shift;

  return { map { $_->presentation_id => 1 } $self->attendances };
}

sub locked {
  my $self = shift;

  return $self->attendances->count;
}

sub allowed_courses {
  my $self = shift;

  return $self->form->year->allowed_courses;
}

sub is_registered {
  my $self = shift;

  return length $self->password;
}

sub is_verified {
  my $self = shift;

  return $self->is_registered && ! $self->verify;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
