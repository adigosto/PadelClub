using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace PadelClub.Services.Database.Migrations;

[DbContext(typeof(PadelClubContext))]
[Migration("20260815190000_NormalizeMembershipStatus")]
public sealed class NormalizeMembershipStatus : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql(
            """
            UPDATE Memberships
            SET Status = CASE WHEN IsActive = 1 THEN 'Active' ELSE 'Cancelled' END
            WHERE Status IS NULL OR LTRIM(RTRIM(Status)) = '';
            """);

        migrationBuilder.AlterColumn<string>(
            name: "Status",
            table: "Memberships",
            type: "nvarchar(30)",
            maxLength: 30,
            nullable: false,
            defaultValue: "Active",
            oldClrType: typeof(string),
            oldType: "nvarchar(30)",
            oldMaxLength: 30);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AlterColumn<string>(
            name: "Status",
            table: "Memberships",
            type: "nvarchar(30)",
            maxLength: 30,
            nullable: false,
            defaultValue: "",
            oldClrType: typeof(string),
            oldType: "nvarchar(30)",
            oldMaxLength: 30,
            oldDefaultValue: "Active");
    }
}
