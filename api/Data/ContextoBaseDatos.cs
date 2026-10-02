using Microsoft.EntityFrameworkCore;
using Tickets.Api.Models;

namespace Tickets.Api.Data;

/// <summary>Conserva el mapeo EF Core previo de la estructura PostgreSQL externa.</summary>
/// <param name="options">Opciones con el proveedor y la conexión configurados en DI.</param>
public class ContextoBaseDatos(DbContextOptions<ContextoBaseDatos> options) : DbContext(options)
{
    public DbSet<Usuario> Users => Set<Usuario>();
    public DbSet<Sucursal> Branches => Set<Sucursal>();
    public DbSet<Ticket> Tickets => Set<Ticket>();
    public DbSet<Evidencia> Evidences => Set<Evidencia>();

    /// <summary>Relaciona los modelos con las tablas, tipos, claves y relaciones existentes.</summary>
    /// <param name="modelBuilder">Constructor del modelo de persistencia de EF Core.</param>
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Usuario>(entity =>
        {
            entity.ToTable("Users");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Username).HasMaxLength(100).IsRequired();
            entity.Property(x => x.PasswordHash).IsRequired();
            entity.Property(x => x.Name).HasMaxLength(200).IsRequired();
            entity.HasIndex(x => x.Username).IsUnique();
        });

        modelBuilder.Entity<Sucursal>(entity =>
        {
            entity.ToTable("Branches");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Name).HasMaxLength(200).IsRequired();
            entity.Property(x => x.Address).HasMaxLength(500).IsRequired();
        });

        modelBuilder.Entity<Ticket>(entity =>
        {
            entity.ToTable("Tickets");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Title).HasMaxLength(200).IsRequired();
            entity.Property(x => x.Description).IsRequired();
            entity.Property(x => x.Status).HasConversion<string>().HasMaxLength(20).IsRequired();
            entity.HasOne<Sucursal>().WithMany().HasForeignKey(x => x.BranchId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<Usuario>().WithMany().HasForeignKey(x => x.TechnicianId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(x => x.BranchId);
            entity.HasIndex(x => new { x.TechnicianId, x.Status });
        });

        modelBuilder.Entity<Evidencia>(entity =>
        {
            entity.ToTable("Evidences");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Description).IsRequired();
            entity.HasOne<Ticket>().WithMany().HasForeignKey(x => x.TicketId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(x => x.TicketId);
        });
    }
}
