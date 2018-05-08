using Nop.Core.Domain.Media;

namespace Nop.Services.Media
{
    public interface IPictureBinaryService
    {
        /// <summary>
        /// Gets a picture binary data
        /// </summary>
        /// <param name="pictureId">Picture identifier</param>
        /// <returns>Picture binary</returns>
        PictureBinary GetPictureBinaryByPictureId(int pictureId);

        /// <summary>
        /// Insert the picture binary data
        /// </summary>
        /// <param name="pictureId">The picture identifier</param>
        /// <param name="binaryData">The picture binary data</param>
        /// <returns>Picture binary</returns>
        PictureBinary InsertPictureBinary(int pictureId, byte[] binaryData);

        /// <summary>
        /// Updates the picture binary data
        /// </summary>
        /// <param name="pictureId">The picture identifier</param>
        /// <param name="binaryData">The picture binary data</param>
        /// <returns>Picture binary</returns>
        PictureBinary UpdatePictureBinary(int pictureId, byte[] binaryData);

        /// <summary>
        /// Deletes a picture binary data
        /// </summary>
        /// <param name="pictureId">Picture identifier</param>
        void DeletePictureBinary(int pictureId);
    }
}