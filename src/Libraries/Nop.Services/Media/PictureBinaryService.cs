using System;
using System.Linq;
using Nop.Core.Data;
using Nop.Core.Domain.Media;
using Nop.Services.Events;

namespace Nop.Services.Media
{
    /// <summary>
    /// PictureBinary service
    /// </summary>
    public partial class PictureBinaryService : IPictureBinaryService
    {
        #region Fields

        private readonly IRepository<PictureBinary> _pictureBinaryRepository;
        private readonly IEventPublisher _eventPublisher;

        #endregion

        #region Ctor

        /// <summary>
        /// Ctor
        /// </summary>
        /// <param name="pictureBinaryRepository">PictureBinary repository</param>
        /// <param name="eventPublisher">Event publisher</param>
        public PictureBinaryService(IRepository<PictureBinary> pictureBinaryRepository,
            IEventPublisher eventPublisher)
        {
            this._pictureBinaryRepository = pictureBinaryRepository;
            this._eventPublisher = eventPublisher;
        }

        #endregion

        #region Utilities

        /// <summary>
        /// Deletes a picture binary data
        /// </summary>
        /// <param name="pictureBinary">Picture binary data</param>
        protected virtual void DeletePictureBinary(PictureBinary pictureBinary)
        {
            if (pictureBinary == null)
                throw new ArgumentNullException(nameof(pictureBinary));

            _pictureBinaryRepository.Delete(pictureBinary);

            //event notification
            _eventPublisher.EntityDeleted(pictureBinary);
        }

        #endregion

        #region Methods

        /// <summary>
        /// Gets a picture binary data
        /// </summary>
        /// <param name="pictureId">Picture identifier</param>
        /// <returns>Picture binary</returns>
        public virtual PictureBinary GetPictureBinaryByPictureId(int pictureId)
        {
            if (pictureId == 0)
                return null;

            return _pictureBinaryRepository.Table.FirstOrDefault(pb => pb.PictureId == pictureId);
        }
        
        /// <summary>
        /// Deletes a picture binary data
        /// </summary>
        /// <param name="pictureId">Picture identifier</param>
        public virtual void DeletePictureBinary(int pictureId)
        {
            DeletePictureBinary(GetPictureBinaryByPictureId(pictureId));
        }
        
        /// <summary>
        /// Updates the picture binary data
        /// </summary>
        /// <param name="pictureId">The picture identifier</param>
        /// <param name="binaryData">The picture binary data</param>
        /// <returns>Picture binary</returns>
        public virtual PictureBinary UpdatePictureBinary(int pictureId, byte[] binaryData)
        {
            var pictureBinary = GetPictureBinaryByPictureId(pictureId);
            var isNew = pictureBinary == null;

            if (isNew)
                pictureBinary = new PictureBinary
                {
                    PictureId = pictureId
                };

            pictureBinary.BinaryData = binaryData;

            if (isNew)
                _pictureBinaryRepository.Insert(pictureBinary);
            else
                _pictureBinaryRepository.Update(pictureBinary);

            return pictureBinary;
        }
        
        /// <summary>
        /// Insert the picture binary data
        /// </summary>
        /// <param name="pictureId">The picture identifier</param>
        /// <param name="binaryData">The picture binary data</param>
        /// <returns>Picture binary</returns>
        public virtual PictureBinary InsertPictureBinary(int pictureId, byte[] binaryData)
        {
            return UpdatePictureBinary(pictureId, binaryData);
        }

        #endregion
    }
}
