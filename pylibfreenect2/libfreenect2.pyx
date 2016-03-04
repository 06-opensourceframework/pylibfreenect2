# coding: utf-8
# cython: boundscheck=True, wraparound=True

"""
API
===

.. important::
    Python API's are designed to minimize differences in C++ and Python; i.e. all
    classes and methods should have the same name; function signatures should
    also be same as possible. For the slight differences, see below in details.


All functionality in ``pylibfreenect2.libfreenect2`` is directly accesible from
the top-level ``pylibfreenect2.*`` namespace.

The sections below are organized by following
`the offical docs <https://openkinect.github.io/libfreenect2/modules.html>`_.

Frame Listeners
---------------

FrameType
^^^^^^^^^

.. autoclass:: pylibfreenect2.FrameType
    :members:

Frame
^^^^^

.. autoclass:: Frame
    :members:

FrameMap
^^^^^^^^

.. autoclass:: FrameMap
    :members:
    :special-members: __getitem__

SyncMultiFrameListener
^^^^^^^^^^^^^^^^^^^^^^

.. autoclass:: SyncMultiFrameListener
    :members:

Initialization and Device Control
---------------------------------

Freenect2Device
^^^^^^^^^^^^^^^

.. autoclass:: Freenect2Device
    :members:

Freenect2
^^^^^^^^^

.. autoclass:: Freenect2
    :members:

ColorCameraParams
^^^^^^^^^^^^^^^^^

.. autoclass:: ColorCameraParams
    :members:

IrCameraParams
^^^^^^^^^^^^^^

.. autoclass:: IrCameraParams
    :members:


Packet Pipelines
----------------

PacketPipeline
^^^^^^^^^^^^^^

.. autoclass:: PacketPipeline
    :members:

CpuPacketPipeline
^^^^^^^^^^^^^^^^^

.. autoclass:: CpuPacketPipeline
    :members:

OpenCLPacketPipeline
^^^^^^^^^^^^^^^^^^^^

.. autoclass:: OpenCLPacketPipeline
    :members:

OpenGLPacketPipeline
^^^^^^^^^^^^^^^^^^^^

.. autoclass:: OpenGLPacketPipeline
    :members:

Registration and Geometry
-------------------------

Registration
^^^^^^^^^^^^

.. autoclass:: Registration
    :members:
"""


import numpy as np

cimport numpy as np
np.import_array()

cimport cython

from libcpp cimport bool
from libcpp.string cimport string
from libcpp.map cimport map

# Import libfreenect2 definitions
from libfreenect2 cimport libfreenect2

# A workaround to access nested cppclass that externed in a separate namespace.
# Nested cppclass Freenect2Device::ColorCameraParams cannot be accesed
# with chained ‘.‘ access (i.e.
# `libfreenect2.Freenect2Device.ColorCameraParams`), here I explicitly import
#  Freenect2Device as _Freenect2Device (to avoid name conflict) and use
# `_Freenect2Device.ColorCameraParams` to access nested cppclass
# ColorCameraParams.
from libfreenect2.libfreenect2 cimport Freenect2Device as _Freenect2Device

from pylibfreenect2 import FrameType

cdef class Frame:
    """Python interface for ``libfreenect2::Frame``.

    The Frame is a container of the C++ pointer ``libfreenect2::Frame*``.

    .. note::
        By default, Frame just keeps a pointer of ``libfreenect2::Frame`` that
        should be allocated and released by SyncMultiFrameListener (i.e. Frame
        itself doesn't own the allocated memory) as in C++. However, if Frame is
        created by providing ``width``, ``height`` and ``bytes_per_pixel``, then
        it allocates necessary memory in ``__cinit__`` and release it in
        ``__dealloc__`` method.

    Attributes
    ----------
    ptr : libfreenect2::Frame*
        Pointer of Frame.

    take_ownership : bool
        If True, the class instance allocates memory for Frame* and release it
        in ``__dealloc__``. If `width`, `height` and `bytes_per_pixel` are given
        in ``__cinit__``, which is necessary to allocate how much memory we need,
        ``take_ownership`` is set to True internally, otherwise False. Note that
        the value itself cannot be set by users.

    frame_type : int
        Underlying frame type.

    Parameters
    ----------
    width : int, optional
        Width of Frame. Default is None.

    height : int, optional
        Height of Frame. Default is None.

    bytes_per_pixel : int, optional
        Bytes per pixels of Frame. Default is None.

    frame_type : int, optional
        Underlying frame type. Default is -1. Used by ``asarray`` method.

    See also
    --------

    pylibfreenect2.FrameType
    """

    cdef libfreenect2.Frame* ptr
    cdef bool take_ownership
    cdef int frame_type

    def __cinit__(self, width=None, height=None, bytes_per_pixel=None,
            int frame_type=-1):
        w,h,b = width, height, bytes_per_pixel
        all_none = (w is None) and (h is None) and (b is None)
        all_not_none = (w is not None) and (h is not None) and (b is not None)
        assert all_none or all_not_none

        self.frame_type = frame_type

        if all_not_none:
            self.take_ownership = True
            self.ptr = new libfreenect2.Frame(
                width, height, bytes_per_pixel, NULL)
        else:
            self.take_ownership = False

    def __dealloc__(self):
        if self.take_ownership and self.ptr is not NULL:
            del self.ptr

    @property
    def timestamp(self):
        """Timestamp"""
        return self.ptr.timestamp

    @property
    def sequence(self):
        """Sequence"""
        return self.ptr.sequence

    @property
    def width(self):
        """Width"""
        return self.ptr.width

    @property
    def height(self):
        """Height"""
        return self.ptr.height

    @property
    def bytes_per_pixel(self):
        """Bytes per pixel"""
        return self.ptr.bytes_per_pixel

    @property
    def exposure(self):
        """Exposure"""
        return self.ptr.exposure

    @property
    def gain(self):
        """Gain"""
        return self.ptr.gain

    @property
    def gamma(self):
        """Gamma"""
        return self.ptr.gamma

    cdef __uint8_data(self):
        cdef np.npy_intp shape[3]
        shape[0] = <np.npy_intp> self.ptr.height
        shape[1] = <np.npy_intp> self.ptr.width
        shape[2] = <np.npy_intp> 4
        cdef np.ndarray array = np.PyArray_SimpleNewFromData(
            3, shape, np.NPY_UINT8, self.ptr.data)

        return array

    cdef __float32_data(self):
        cdef np.npy_intp shape[2]
        shape[0] = <np.npy_intp> self.ptr.height
        shape[1] = <np.npy_intp> self.ptr.width
        cdef np.ndarray array = np.PyArray_SimpleNewFromData(
            2, shape, np.NPY_FLOAT32, self.ptr.data)

        return array

    def astype(self, data_type):
        """Frame to ``numpy.ndarray`` conversion with specified data type.

        Internal data of Frame can be represented as:

        - 3d array of ``numpy.uint8`` for color
        - 2d array of ``numpy.float32`` for IR and depth

        Returns
        -------
        array : ``numpy.ndarray``, shape: ``(height, width)`` for IR and depth,
        ``(4, height, width)`` for Color.
            Array of internal frame.

        Raises
        ------
        ValueError
            - If a type that is neither ``numpy.uint8`` nor ``numpy.float32`` is specified

        """
        if data_type != np.uint8 and data_type != np.float32:
            raise ValueError("np.uint8 or np.float32 is only supported")
        if data_type == np.uint8:
            return self.__uint8_data()
        else:
            return self.__float32_data()

    def asarray(self):
        """Frame to ``numpy.ndarray`` conversion

        Returns
        -------
        array : ``numpy.ndarray``, shape: ``(height, width)`` for IR and depth,
        ``(4, height, width)`` for Color.
            Array of internal frame.

        Raises
        ------
        ValueError
            - If underlying frame type cannot be determined.

        """
        if self.frame_type < 0:
            raise ValueError("Cannnot determine type of raw data. Use astype instead.")

        if self.frame_type == FrameType.Color:
            return self.astype(np.uint8)
        elif self.frame_type == FrameType.Ir or self.frame_type == FrameType.Depth:
            return self.astype(np.float32)
        else:
            assert False


cdef class FrameListener:
    cdef libfreenect2.FrameListener* listener_ptr_alias


cdef intenum_to_frame_type(int n):
    if n == FrameType.Color:
        return libfreenect2.Color
    elif n == FrameType.Ir:
        return libfreenect2.Ir
    elif n == FrameType.Depth:
        return libfreenect2.Depth
    else:
        raise ValueError("Not supported")

cdef str_to_int_frame_type(str s):
    s = s.lower()
    if s == "color":
        return FrameType.Color
    elif s == "ir":
        return FrameType.Ir
    elif s == "depth":
        return FrameType.Depth
    else:
        raise ValueError("Not supported")

cdef str_to_frame_type(str s):
    return intenum_to_frame_type(str_to_int_frame_type(s))


cdef class FrameMap:
    """Python interface for ``libfreenect2::FrameMap``.

    The FrameMap is a container of C++ value ``libfreenect2::FrameMap`` (aliased
    to ``std::map<libfreenect2::Frame::Type,libfreenect2::Frame*>`` in C++).

    .. note::
        By default, FrameMap just keeps a reference of ``libfreenect2::FrameMap``
        that should be allcoated and released by SyncMultiFrameListener (i.e.
        FrameMap itself doesn't own the allocated memory) as in C++.

    Attributes
    ----------
    internal_frame_map : std::map<libfreenect2::Frame::Type, libfreenect2::Frame*>
        Internal FrameMap.

    """
    cdef map[libfreenect2.LibFreenect2FrameType, libfreenect2.Frame*] internal_frame_map
    cdef bool take_ownership

    def __cinit__(self, bool take_ownership=False):
        self.take_ownership = take_ownership

    def __dealloc__(self):
        # Since libfreenect2 is for now designed to release FrameMap explicitly,
        # __dealloc__  do nothing by default (take_ownership = False)
        if self.take_ownership:
            # similar to SyncMultiFrameListener::release(FrameMap &frame)
            # do nothing if already released
            for key in self.internal_frame_map:
                if key.second != NULL:
                    del key.second
                    key.second = NULL

    def __getitem__(self, key):
        """Get access to the internal FrameMap.

        This allows the following dict-like syntax:

        .. code-block:: python

            color = frames[pylibfreenect2.FrameType.Color]

        .. code-block:: python

            color = frames['color']

        .. code-block:: python

            color = frames[1] # with IntEnum value

        The key can be of ``FrameType`` (a subclass of IntEnum), str or int type
        as shown above.

        Parameters
        ----------
        key : ``FrameType``, str or int
            Key for the internal FrameMap. available str keys are ``color``,
            ``ir`` and ``depth``.

        Returns
        -------
        frame : Frame
            Frame for the specified key.

        Raises
        ------
        KeyError
            if unknown key is specified

        See also
        --------

        pylibfreenect2.FrameType

        """
        cdef libfreenect2.LibFreenect2FrameType frame_type
        cdef intkey

        if isinstance(key, int) or isinstance(key, FrameType):
            frame_type = intenum_to_frame_type(key)
            intkey = key
        elif isinstance(key, str):
            frame_type = str_to_frame_type(key)
            intkey = str_to_int_frame_type(key)
        else:
            raise KeyError("")

        cdef libfreenect2.Frame* frame_ptr = self.internal_frame_map[frame_type]
        cdef Frame frame = Frame(frame_type=intkey)
        frame.ptr = frame_ptr
        return frame


cdef class SyncMultiFrameListener(FrameListener):
    """Python interface for ``libfreenect2::SyncMultiFrameListener``.

    The SyncMultiFrameListener is a container of
    C++ pointer ``libfreenect2::SyncMultiFrameListener*``. The pointer of
    SyncMultiFrameListener is allocated in ``__cinit__`` and released in
    ``__dealloc__`` method.

    Parameters
    ----------
    frame_types : unsigned int, optional
        Frame types that we want to listen. It can be logical OR of:

            - ``FrameType.Color``
            - ``FrameType.Ir``
            - ``FrameType.Depth``

        Default is ``FrameType.Color | FrameType.Ir | FrameType.Depth``

    Attributes
    ----------
    ptr : libfreenect2.SyncMultiFrameListener*
        Pointer of ``libfreenect2::SyncMultiFrameListener``

    listener_ptr_alias : libfreenect2.FrameListener*
        Pointer of ``libfreenect2::FrameListener``. This is necessary to call
        methods that operate on ``libfreenect2::FrameListener*``, not
        ``libfreenect2::SyncMultiFrameListener``.

    See also
    --------

    pylibfreenect2.FrameType

    """

    cdef libfreenect2.SyncMultiFrameListener* ptr

    def __cinit__(self, unsigned int frame_types=<unsigned int>(
                        FrameType.Color | FrameType.Ir | FrameType.Depth)):
        self.ptr = new libfreenect2.SyncMultiFrameListener(frame_types)
        self.listener_ptr_alias = <libfreenect2.FrameListener*> self.ptr

    def __dealloc__(self):
        if self.ptr is not NULL:
            del self.ptr

    def hasNewFrame(self):
        """Same as ``libfreenect2::SyncMultiFrameListener::hasNewFrame()``.

        Returns
        -------
        r : Bool
            True if SyncMultiFrameListener has a new frame, False otherwise.
        """
        return self.ptr.hasNewFrame()

    def waitForNewFrame(self, FrameMap frame_map=None):
        """Same as ``libfreenect2::SyncMultiFrameListener::waitForNewFrame(Frame&)``.

        Parameters
        ----------
        frame_map : FrameMap, optional
            If not None, SyncMultiFrameListener write to it inplace, otherwise
            a new FrameMap is allocated within the function and then returned.

        Returns
        -------
        frame_map : FrameMap
            FrameMap.

            .. note::
                FrameMap must be releaseed by call-side by calling ``release``
                function.

        .. warning::

            Function signature can be different between Python and C++.

        Suppose the following C++ code:

        .. code-block:: c++

            libfreenect2::FrameMap frames;
            listener->waitForNewFrame(frames);

        This can be translated in Python as follows:

        .. code-block:: python

            frames = listener.waitForNewFrame()

        or you can write it more similar to C++:

        .. code-block:: python

            frames = pylibfreenect2.FrameMap()
            listener.waitForNewFrame(frames)

        """
        if frame_map is None:
            frame_map = FrameMap(take_ownership=False)
        self.ptr.waitForNewFrame(frame_map.internal_frame_map)
        return frame_map


    def release(self, FrameMap frame_map):
        """Same as ``libfreenect2::SyncMultiFrameListener::release(Frame&)``.

        Parameters
        ----------
        frame_map : FrameMap
            FrameMap.
        """
        self.ptr.release(frame_map.internal_frame_map)


cdef class ColorCameraParams:
    """Python interface for ``libfreenect2::ColorCameraParams``.

    Attributes
    ----------
    params : libfreenect2.Freenect2Device.ColorCameraParams
    """
    cdef _Freenect2Device.ColorCameraParams params

    # TODO: wrap all instance variables
    @property
    def fx(self):
        """Fx"""
        return self.params.fx

    @property
    def fy(self):
        """Fy"""
        return self.params.fy

    @property
    def cx(self):
        """Cx"""
        return self.params.cx

    @property
    def cy(self):
        """Cy"""
        return self.params.cy


cdef class IrCameraParams:
    """Python interface for ``libfreenect2::IrCameraParams``.

    Attributes
    ----------
    params : libfreenect2.Freenect2Device.IrCameraParams
    """
    cdef _Freenect2Device.IrCameraParams params

    @property
    def fx(self):
        """Fx"""
        return self.params.fx

    @property
    def fy(self):
        """Fy"""
        return self.params.fy

    @property
    def cx(self):
        """Cx"""
        return self.params.cx

    @property
    def cy(self):
        """Cy"""
        return self.params.cy

cdef class Registration:
    """Python interface for ``libfreenect2::Registration``.

    The Registration is a container of C++ pointer
    ``libfreenect2::Registration*``. The pointer of Registration is allocated
    in ``__cinit__`` and released in ``__dealloc__`` method.

    Attributes
    ----------
    ptr : ``libfreenect2::Registration*``

    Parameters
    ----------
    irparams : IrCameraParams
        IR camera parameters.

    cparams : ColorCameraParams
        Color camera parameters.
    """
    cdef libfreenect2.Registration* ptr

    def __cinit__(self, IrCameraParams irparams, ColorCameraParams cparams):
        cdef _Freenect2Device.IrCameraParams i = irparams.params
        cdef _Freenect2Device.ColorCameraParams c = cparams.params
        self.ptr = new libfreenect2.Registration(i, c)

    def __dealloc__(self):
        if self.ptr is not NULL:
            del self.ptr

    def apply(self, Frame rgb, Frame depth, Frame undistored,
            Frame registered, enable_filter=True, Frame bigdepth=None):
        """Same as ``libfreenect2::Registration::apply``.

        Parameters
        ----------
        rgb : Frame
        depth : Frame
        registered : Frame
        enable_filter : Bool, optional
        bigdepth : Frame, optional
        """
        assert rgb.take_ownership == False
        assert depth.take_ownership == False
        assert undistored.take_ownership == True
        assert registered.take_ownership == True
        assert bigdepth is None or bigdepth.take_ownership == True

        cdef libfreenect2.Frame* bigdepth_ptr = <libfreenect2.Frame*>(NULL) \
            if bigdepth is None else bigdepth.ptr

        self.ptr.apply(rgb.ptr, depth.ptr, undistored.ptr, registered.ptr,
            enable_filter, bigdepth_ptr)


# MUST be declared before backend specific includes
cdef class PacketPipeline:
    """Base class for other pipeline classes.

    Attributes
    ----------
    pipeline_ptr_alias : ``libfreenect2::PacketPipeline*``
    owened_by_device : bool

    See also
    --------
    pylibfreenect2.CpuPacketPipeline
    pylibfreenect2.OpenCLPacketPipeline
    pylibfreenect2.OpenGLPacketPipeline
    """
    cdef libfreenect2.PacketPipeline* pipeline_ptr_alias

    # NOTE: once device is opened with pipeline, pipeline will be
    # releaseed in the destructor of Freenect2DeviceImpl
    cdef bool owned_by_device


cdef class CpuPacketPipeline(PacketPipeline):
    """Pipeline with CPU depth processing.

    Attributes
    ----------
    pipeline : `libfreenect2::CpuPacketPipeline*`
    """
    cdef libfreenect2.CpuPacketPipeline* pipeline

    def __cinit__(self):
        self.pipeline = new libfreenect2.CpuPacketPipeline()
        self.pipeline_ptr_alias = <libfreenect2.PacketPipeline*>self.pipeline
        self.owned_by_device = False

    def __dealloc__(self):
        if not self.owned_by_device:
            if self.pipeline is not NULL:
                del self.pipeline

IF LIBFREENECT2_WITH_OPENGL_SUPPORT == True:
    include "opengl_packet_pipeline.pxi"

IF LIBFREENECT2_WITH_OPENCL_SUPPORT == True:
    include "opencl_packet_pipeline.pxi"


cdef class Freenect2Device:
    """Python interface for ``libfreenect2::Freenect2Device``.

    The Freenect2Device is a container of C++ pointer
    ``libfreenect2::Freenect2Device*``.

    Attributes
    ----------
    ptr : ``libfreenect2::Freenect2Device*``

    See also
    --------
    pylibfreenect2.Freenect2

    """

    cdef _Freenect2Device* ptr

    def getSerialNumber(self):
        """Same as ``libfreenect2::Freenect2Device::getSerialNumber()``"""
        return self.ptr.getSerialNumber()

    def getFirmwareVersion(self):
        """Same as ``libfreenect2::Freenect2Device::getFirmwareVersion()``"""
        return self.ptr.getFirmwareVersion()

    def getColorCameraParams(self):
        """Same as ``libfreenect2::Freenect2Device::getColorCameraParams()``"""
        cdef _Freenect2Device.ColorCameraParams params
        params = self.ptr.getColorCameraParams()
        cdef ColorCameraParams pyparams = ColorCameraParams()
        pyparams.params = params
        return pyparams

    def getIrCameraParams(self):
        """Same as ``libfreenect2::Freenect2Device::getIrCameraParams()``"""
        cdef _Freenect2Device.IrCameraParams params
        params = self.ptr.getIrCameraParams()
        cdef IrCameraParams pyparams = IrCameraParams()
        pyparams.params = params
        return pyparams

    def setColorFrameListener(self, FrameListener listener):
        """Same as
        ``libfreenect2::Freenect2Device::setColorFrameListener(FrameListener*)``
        """
        self.ptr.setColorFrameListener(listener.listener_ptr_alias)

    def setIrAndDepthFrameListener(self, FrameListener listener):
        """Same as
        ``libfreenect2::Freenect2Device::setIrAndDepthFrameListener(FrameListener*)``
        """
        self.ptr.setIrAndDepthFrameListener(listener.listener_ptr_alias)

    def start(self):
        """Same as ``libfreenect2::Freenect2Device::start()``"""
        self.ptr.start()

    def stop(self):
        """Same as ``libfreenect2::Freenect2Device::stop()``"""
        self.ptr.stop()

    def close(self):
        """Same as ``libfreenect2::Freenect2Device::close()``"""
        self.ptr.close()


cdef class Freenect2:
    """Python interface for ``libfreenect2::Freenect2``.

    The Freenect2 is a container of C++ pointer
    ``libfreenect2::Freenect2*``. The pointer of Freenect2 is allocated
    in ``__cinit__`` and released in ``__dealloc__`` method.

    Attributes
    ----------
    ptr : ``libfreenect2::Freenect2*``

    See also
    --------
    pylibfreenect2.Freenect2Device

    """

    cdef libfreenect2.Freenect2* ptr

    def __cinit__(self):
        self.ptr = new libfreenect2.Freenect2();

    def __dealloc__(self):
        if self.ptr is not NULL:
            del self.ptr

    def enumerateDevices(self):
        """Same as ``libfreenect2::Freenect2::enumerateDevices()``"""
        return self.ptr.enumerateDevices()

    def getDeviceSerialNumber(self, int idx):
        """Same as ``libfreenect2::Freenect2::getDeviceSerialNumber(int)``"""
        return self.ptr.getDeviceSerialNumber(idx)

    def getDefaultDeviceSerialNumber(self):
        """Same as ``libfreenect2::Freenect2::getDefaultDeviceSerialNumber()``"""
        return self.ptr.getDefaultDeviceSerialNumber()

    cdef __openDevice__intidx(self, int idx, PacketPipeline pipeline):
        cdef _Freenect2Device* dev_ptr
        if pipeline is None:
            dev_ptr = self.ptr.openDevice(idx)
        else:
            dev_ptr = self.ptr.openDevice(idx, pipeline.pipeline_ptr_alias)
            pipeline.owned_by_device = True

        cdef Freenect2Device device = Freenect2Device()
        device.ptr = dev_ptr
        return device

    cdef __openDevice__stridx(self, string serial, PacketPipeline pipeline):
        cdef _Freenect2Device* dev_ptr
        if pipeline is None:
            dev_ptr = self.ptr.openDevice(serial)
        else:
            dev_ptr = self.ptr.openDevice(serial, pipeline.pipeline_ptr_alias)
            pipeline.owned_by_device = True

        cdef Freenect2Device device = Freenect2Device()
        device.ptr = dev_ptr
        return device

    def openDevice(self, name, PacketPipeline pipeline=None):
        """Open device by serial number or index

        Parameters
        ----------
        name : int or str
            Serial number (str) or device index (int)

        pipeline : PacketPipeline, optional
            Pipeline. Default is None.

        Raises
        ------
        ValueError
            If invalid name is specified.

        """
        if isinstance(name, int):
            return self.__openDevice__intidx(name, pipeline)
        elif isinstance(name, str) or isinstance(name, bytes):
            return self.__openDevice__stridx(name, pipeline)
        else:
            raise ValueError("device name must be of str, bytes or integer type")

    def openDefaultDevice(self, PacketPipeline pipeline=None):
        """Open the first device

        Parameters
        ----------
        pipeline : PacketPipeline, optional
            Pipeline. Default is None.

        Returns
        -------
        device : Freenect2Device

        """
        cdef _Freenect2Device* dev_ptr

        if pipeline is None:
            dev_ptr = self.ptr.openDefaultDevice()
        else:
            dev_ptr = self.ptr.openDefaultDevice(pipeline.pipeline_ptr_alias)
            pipeline.owned_by_device = True

        cdef Freenect2Device device = Freenect2Device()
        device.ptr = dev_ptr
        return device
