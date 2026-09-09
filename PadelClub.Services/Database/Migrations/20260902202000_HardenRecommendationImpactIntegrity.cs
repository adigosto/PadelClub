using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;
using PadelClub.Services.Database;

#nullable disable

namespace PadelClub.Services.Database.Migrations;

/// <inheritdoc />
[DbContext(typeof(PadelClubContext))]
[Migration("20260902202000_HardenRecommendationImpactIntegrity")]
public partial class HardenRecommendationImpactIntegrity : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // Existing rows predate server-owned provenance. They remain the
        // conservative enum default (Unverified) and therefore cannot become
        // mature operational evidence simply through this migration.
        migrationBuilder.AddColumn<int>(
            name: "TelemetrySource",
            table: "RecommendationExposures",
            type: "int",
            nullable: false,
            defaultValue: 0);

        migrationBuilder.CreateIndex(
            name: "IX_RecommendationExposures_TelemetrySource_ServedAtUtc",
            table: "RecommendationExposures",
            columns: new[] { "TelemetrySource", "ServedAtUtc" });
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropIndex(
            name: "IX_RecommendationExposures_TelemetrySource_ServedAtUtc",
            table: "RecommendationExposures");

        migrationBuilder.DropColumn(
            name: "TelemetrySource",
            table: "RecommendationExposures");
    }

    /// <summary>
    /// Migration execution uses <see cref="Up"/> and <see cref="Down"/>;
    /// the complete target model is maintained in the current model snapshot.
    /// This compact target fragment documents the changed relational shape.
    /// </summary>
    protected override void BuildTargetModel(ModelBuilder modelBuilder)
    {
#pragma warning disable 612, 618
        modelBuilder
            .HasAnnotation("ProductVersion", "8.0.10")
            .HasAnnotation("Relational:MaxIdentifierLength", 128);

        SqlServerModelBuilderExtensions.UseIdentityColumns(modelBuilder);

        modelBuilder.Entity("PadelClub.Services.Database.RecommendationExposure", entity =>
        {
            entity.Property<Guid>("Id")
                .ValueGeneratedOnAdd()
                .HasColumnType("uniqueidentifier");
            entity.Property<string>("AlgorithmVersion")
                .IsRequired()
                .HasMaxLength(120)
                .HasColumnType("nvarchar(120)");
            entity.Property<DateTime?>("ClickedAtUtc").HasColumnType("datetime2");
            entity.Property<int>("ProductId").HasColumnType("int");
            entity.Property<DateTime?>("PurchasedAtUtc").HasColumnType("datetime2");
            entity.Property<int?>("PurchasedOrderId").HasColumnType("int");
            entity.Property<int>("Rank").HasColumnType("int");
            entity.Property<DateTime>("ServedAtUtc").HasColumnType("datetime2");
            entity.Property<string>("Strategy")
                .IsRequired()
                .HasMaxLength(80)
                .HasColumnType("nvarchar(80)");
            entity.Property<RecommendationTelemetrySource>("TelemetrySource")
                .ValueGeneratedOnAdd()
                .HasColumnType("int")
                .HasDefaultValue(RecommendationTelemetrySource.Unverified);
            entity.Property<int>("UserId").HasColumnType("int");
            entity.HasKey("Id");
            entity.HasIndex("PurchasedOrderId");
            entity.HasIndex("ProductId", "ServedAtUtc");
            entity.HasIndex("TelemetrySource", "ServedAtUtc");
            entity.HasIndex("UserId", "ServedAtUtc");
            entity.ToTable("RecommendationExposures");
        });
#pragma warning restore 612, 618
    }
}
