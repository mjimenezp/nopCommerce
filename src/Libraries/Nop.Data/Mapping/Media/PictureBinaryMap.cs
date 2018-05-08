using Nop.Core.Domain.Media;

namespace Nop.Data.Mapping.Media
{
    /// <summary>
    /// Mapping class
    /// </summary>
    public partial class PictureBinaryMap : NopEntityTypeConfiguration<PictureBinary>
    {
        /// <summary>
        /// Ctor
        /// </summary>
        public PictureBinaryMap()
        {
            this.ToTable("PictureBinary");
            this.HasKey(p => p.Id);
            this.Property(p => p.BinaryData).IsRequired().IsMaxLength();

            this.HasRequired(p => p.Picture)
                .WithMany()
                .HasForeignKey(p => p.PictureId)
                .WillCascadeOnDelete();
        }
    }
}