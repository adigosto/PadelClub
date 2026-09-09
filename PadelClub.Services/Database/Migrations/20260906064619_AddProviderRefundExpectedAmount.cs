using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PadelClub.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class AddProviderRefundExpectedAmount : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "ExpectedRefundedAmount",
                table: "ProviderRefundOperations",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 0m);

            // A table created by the preceding migration normally has no
            // operations yet. If an upgrade does contain old pending rows,
            // reserve their amounts in deterministic creation order so a
            // retry cannot undercount the local refund total after rollout.
            migrationBuilder.Sql("""
                ;WITH [PendingRefundTotals] AS
                (
                    SELECT [operation].[Id],
                           [payment].[RefundedAmount] +
                           SUM([operation].[Amount]) OVER
                           (
                               PARTITION BY [operation].[PaymentId]
                               ORDER BY [operation].[CreatedAtUtc], [operation].[Id]
                               ROWS UNBOUNDED PRECEDING
                           ) AS [ExpectedRefundedAmount]
                    FROM [ProviderRefundOperations] AS [operation]
                    INNER JOIN [Payments] AS [payment] ON [payment].[Id] = [operation].[PaymentId]
                    WHERE [operation].[Status] = N'Pending'
                )
                UPDATE [operation]
                SET [ExpectedRefundedAmount] = [pending].[ExpectedRefundedAmount]
                FROM [ProviderRefundOperations] AS [operation]
                INNER JOIN [PendingRefundTotals] AS [pending] ON [pending].[Id] = [operation].[Id]
                WHERE [operation].[ExpectedRefundedAmount] = 0;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ExpectedRefundedAmount",
                table: "ProviderRefundOperations");
        }
    }
}
