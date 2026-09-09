using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace PadelClub.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class AddMembershipTypeReferences : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "MembershipTypeReferenceId",
                table: "Memberships",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "MembershipTypeReferences",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MembershipTypeReferences", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "MembershipTypeReferences",
                columns: new[] { "Id", "IsActive", "Name" },
                values: new object[,]
                {
                    { 1, true, "Basic" },
                    { 2, true, "Premium" },
                    { 3, true, "VIP" }
                });

            migrationBuilder.Sql("""
                INSERT INTO MembershipTypeReferences (Name, IsActive)
                SELECT DISTINCT m.MembershipType, 1
                FROM Memberships m
                WHERE NULLIF(LTRIM(RTRIM(m.MembershipType)), '') IS NOT NULL
                  AND NOT EXISTS (
                      SELECT 1
                      FROM MembershipTypeReferences r
                      WHERE r.Name = m.MembershipType);

                UPDATE m
                SET MembershipTypeReferenceId = r.Id
                FROM Memberships m
                INNER JOIN MembershipTypeReferences r ON r.Name = m.MembershipType;
                """);

            migrationBuilder.CreateIndex(
                name: "IX_Memberships_MembershipTypeReferenceId",
                table: "Memberships",
                column: "MembershipTypeReferenceId");

            migrationBuilder.CreateIndex(
                name: "IX_MembershipTypeReferences_Name",
                table: "MembershipTypeReferences",
                column: "Name",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Memberships_MembershipTypeReferences_MembershipTypeReferenceId",
                table: "Memberships",
                column: "MembershipTypeReferenceId",
                principalTable: "MembershipTypeReferences",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Memberships_MembershipTypeReferences_MembershipTypeReferenceId",
                table: "Memberships");

            migrationBuilder.DropTable(
                name: "MembershipTypeReferences");

            migrationBuilder.DropIndex(
                name: "IX_Memberships_MembershipTypeReferenceId",
                table: "Memberships");

            migrationBuilder.DropColumn(
                name: "MembershipTypeReferenceId",
                table: "Memberships");
        }
    }
}
