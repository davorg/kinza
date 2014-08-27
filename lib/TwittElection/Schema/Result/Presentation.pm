use utf8;
package TwittElection::Schema::Result::Presentation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

TwittElection::Schema::Result::Presentation

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

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "course_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "term_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
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

Related object: L<TwittElection::Schema::Result::Attendance>

=cut

__PACKAGE__->has_many(
  "attendances",
  "TwittElection::Schema::Result::Attendance",
  { "foreign.presentation_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 course

Type: belongs_to

Related object: L<TwittElection::Schema::Result::Course>

=cut

__PACKAGE__->belongs_to(
  "course",
  "TwittElection::Schema::Result::Course",
  { id => "course_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 term

Type: belongs_to

Related object: L<TwittElection::Schema::Result::Term>

=cut

__PACKAGE__->belongs_to(
  "term",
  "TwittElection::Schema::Result::Term",
  { id => "term_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07039 @ 2014-08-27 19:55:04
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:D6XBPXU89BAiymBrxAdLSA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
