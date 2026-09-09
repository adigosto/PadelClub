using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PadelClub.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class AddOrderDemoProvenance : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsSeededForDemo",
                table: "Orders",
                type: "bit",
                nullable: false,
                defaultValue: false);

            // Preserve the provenance of development orders that existed
            // before the dedicated flag. Their product recommendations remain
            // useful for a local demo, but they are not quality evidence.
            migrationBuilder.Sql(
                "UPDATE [Orders] SET [IsSeededForDemo] = CAST(1 AS bit) WHERE [OrderNumber] LIKE N'DEMO-%';");

            migrationBuilder.CreateIndex(
                name: "IX_Orders_Status_IsSeededForDemo_DeliveredAt",
                table: "Orders",
                columns: new[] { "Status", "IsSeededForDemo", "DeliveredAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Orders_Status_IsSeededForDemo_DeliveredAt",
                table: "Orders");

            migrationBuilder.DropColumn(
                name: "IsSeededForDemo",
                table: "Orders");
        }
    }
}
