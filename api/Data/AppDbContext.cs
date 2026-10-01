using Microsoft.EntityFrameworkCore;
using Tickets.Api.Models;

namespace Tickets.Api.Data;

/// <summary>
/// Conserva el mapeo EF Core previo de la estructura PostgreSQL externa.
/// No se registra ni utiliza actualmente: las lecturas usan IConexion.
/// Se retiene junto con la dependencia hasta decidir su eliminación; no crea esquema.
/// </summary>
/// <param name="options">Opciones con el proveedor y la conexión configurados en DI.</param>
public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Branch> Branches => Set<Branch>();
    public DbSet<Ticket> Tickets => Set<Ticket>();
    public DbSet<Evidence> Evidences => Set<Evidence>();

    /// <summary>
    /// Relaciona los modelos con las tablas, tipos, claves y relaciones existentes.
    /// Usa la configuración explícita de EF Core para interpretar correctamente
    /// los resultados SQL sin delegarle la creación de la base de datos.
    /// Los CHECK de la estructura oficial se definen en DATABASE.md.
    /// </summary>
    /// <param name="modelBuilder">Constructor del modelo de persistencia de EF Core.</param>
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>(entity =>
        {
            entity.ToTable("Users");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Username).HasMaxLength(100).IsRequired();
            entity.Property(x => x.PasswordHash).IsRequired();
            entity.Property(x => x.Name).HasMaxLength(200).IsRequired();
            entity.HasIndex(x => x.Username).IsUnique();
        });

        modelBuilder.Entity<Branch>(entity =>
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
            entity.HasOne<Branch>().WithMany().HasForeignKey(x => x.BranchId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<User>().WithMany().HasForeignKey(x => x.TechnicianId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(x => x.BranchId);
            entity.HasIndex(x => new { x.TechnicianId, x.Status });
        });

        modelBuilder.Entity<Evidence>(entity =>
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
