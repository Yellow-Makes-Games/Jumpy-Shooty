// Jumpy Shooty's killcam encoder: raw frames in, an H.264 MP4 out, using the video
// encoder every Windows 10/11 PC has (Media Foundation's Sink Writer), with an AAC
// sound track.
//
//   Mp4Encoder.exe <out.mp4> <width> <height> <fps> <bitrate bits/s>
//
// Reads from stdin, until it closes: each frame as "V" then width * height * 4 bytes,
// RGBA, top row first (what Godot's Image.get_data() gives); then the sound as "A",
// the sample rate (44100) and byte count as little-endian int32s, and 16-bit stereo
// samples. No sound: a silent track. Exits 0 when the file is written
// (printing "OK <frames>" if anyone still listens); prints "ERROR <why>" to stderr and
// exits 1 if not.
//
// Built with the C# compiler that comes with .NET Framework (see build.ps1), so it runs
// on any Windows 10/11 PC with nothing to install. game/ui/killcam_export.gd ships it in
// the game's pack and runs it.

using System;
using System.IO;
using System.Runtime.InteropServices;

static class Mp4Encoder
{
    static int Main(string[] args)
    {
        try
        {
            if (args.Length < 5)
            {
                Say(Console.Error, "ERROR usage: Mp4Encoder <out.mp4> <width> <height> <fps> <bitrate>");
                return 1;
            }
            int frames = Run(args[0], int.Parse(args[1]), int.Parse(args[2]), int.Parse(args[3]), int.Parse(args[4]));
            Say(Console.Out, "OK " + frames);
            return 0;
        }
        catch (Exception e)
        {
            Say(Console.Error, "ERROR " + e.GetType().Name + ": " + e.Message.Replace("\r", " ").Replace("\n", " "));
            return 1;
        }
    }

    // The game may have closed its end of the pipe already: never fail over a message.
    static void Say(TextWriter to, string line)
    {
        try { to.WriteLine(line); to.Flush(); } catch (Exception) { }
    }

    const int RATE = 44100;        // the sound track: 16-bit stereo at this rate...
    const int AAC_BYTES = 24000;   // ...encoded as AAC at 192 kbit/s

    static int Run(string outPath, int width, int height, int fps, int bitrate)
    {
        int frameBytes = width * height * 4;
        long step = 10000000L / fps;   // 100 ns units
        Check(MF.MFStartup(0x20070, 0), "MFStartup");
        int count = 0;
        try
        {
            IMFAttributes attrs;
            Check(MF.MFCreateAttributes(out attrs, 2), "attributes");
            attrs.SetUINT32(MF.MF_READWRITE_ENABLE_HARDWARE_TRANSFORMS, 1);
            attrs.SetUINT32(MF.MF_SINK_WRITER_DISABLE_THROTTLING, 1);
            string path = Path.GetFullPath(outPath);
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            if (File.Exists(path))
                File.Delete(path);
            IMFSinkWriter writer;
            Check(MF.MFCreateSinkWriterFromURL(path, IntPtr.Zero, attrs, out writer), "sink writer");

            // The picture: H.264, High profile, from 32-bit BGRX frames, top row first.
            IMFMediaType outType;
            Check(MF.MFCreateMediaType(out outType), "media type");
            outType.SetGUID(MF.MF_MT_MAJOR_TYPE, MF.MFMediaType_Video);
            outType.SetGUID(MF.MF_MT_SUBTYPE, MF.MFVideoFormat_H264);
            outType.SetUINT32(MF.MF_MT_AVG_BITRATE, bitrate);
            outType.SetUINT32(MF.MF_MT_INTERLACE_MODE, 2);   // progressive
            outType.SetUINT32(MF.MF_MT_MPEG2_PROFILE, 100);  // High
            outType.SetUINT64(MF.MF_MT_FRAME_SIZE, Pack(width, height));
            outType.SetUINT64(MF.MF_MT_FRAME_RATE, Pack(fps, 1));
            outType.SetUINT64(MF.MF_MT_PIXEL_ASPECT_RATIO, Pack(1, 1));
            int video;
            Check(writer.AddStream(outType, out video), "add video");
            IMFMediaType inType;
            Check(MF.MFCreateMediaType(out inType), "media type");
            inType.SetGUID(MF.MF_MT_MAJOR_TYPE, MF.MFMediaType_Video);
            inType.SetGUID(MF.MF_MT_SUBTYPE, MF.MFVideoFormat_RGB32);
            inType.SetUINT32(MF.MF_MT_INTERLACE_MODE, 2);
            inType.SetUINT32(MF.MF_MT_DEFAULT_STRIDE, width * 4);
            inType.SetUINT64(MF.MF_MT_FRAME_SIZE, Pack(width, height));
            inType.SetUINT64(MF.MF_MT_FRAME_RATE, Pack(fps, 1));
            inType.SetUINT64(MF.MF_MT_PIXEL_ASPECT_RATIO, Pack(1, 1));
            Check(writer.SetInputMediaType(video, inType, IntPtr.Zero), "video input");

            // The sound: AAC, from 16-bit stereo PCM.
            IMFMediaType aacType;
            Check(MF.MFCreateMediaType(out aacType), "media type");
            aacType.SetGUID(MF.MF_MT_MAJOR_TYPE, MF.MFMediaType_Audio);
            aacType.SetGUID(MF.MF_MT_SUBTYPE, MF.MFAudioFormat_AAC);
            aacType.SetUINT32(MF.MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
            aacType.SetUINT32(MF.MF_MT_AUDIO_SAMPLES_PER_SECOND, RATE);
            aacType.SetUINT32(MF.MF_MT_AUDIO_NUM_CHANNELS, 2);
            aacType.SetUINT32(MF.MF_MT_AUDIO_AVG_BYTES_PER_SECOND, AAC_BYTES);
            int audio;
            Check(writer.AddStream(aacType, out audio), "add audio");
            IMFMediaType pcmType;
            Check(MF.MFCreateMediaType(out pcmType), "media type");
            pcmType.SetGUID(MF.MF_MT_MAJOR_TYPE, MF.MFMediaType_Audio);
            pcmType.SetGUID(MF.MF_MT_SUBTYPE, MF.MFAudioFormat_PCM);
            pcmType.SetUINT32(MF.MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
            pcmType.SetUINT32(MF.MF_MT_AUDIO_SAMPLES_PER_SECOND, RATE);
            pcmType.SetUINT32(MF.MF_MT_AUDIO_NUM_CHANNELS, 2);
            pcmType.SetUINT32(MF.MF_MT_AUDIO_BLOCK_ALIGNMENT, 4);
            pcmType.SetUINT32(MF.MF_MT_AUDIO_AVG_BYTES_PER_SECOND, RATE * 4);
            Check(writer.SetInputMediaType(audio, pcmType, IntPtr.Zero), "audio input");
            Check(writer.BeginWriting(), "begin");

            // stdin: "V" + a frame, any number of times; then (maybe) "A" + rate + byte
            // count (two little-endian int32) + that many bytes of sound.
            Stream input = Console.OpenStandardInput();
            byte[] frame = new byte[frameBytes];
            byte[] sound = null;
            while (true)
            {
                int tag = input.ReadByte();
                if (tag == 'V')
                {
                    if (!ReadFully(input, frame))
                        break;
                    RgbaToBgra(frame);
                    Write(writer, video, frame, frameBytes, step * count, step);
                    count++;
                }
                else if (tag == 'A')
                {
                    byte[] head = new byte[8];
                    if (!ReadFully(input, head))
                        break;
                    int rate = BitConverter.ToInt32(head, 0);
                    int bytes = BitConverter.ToInt32(head, 4);
                    if (rate != RATE || bytes < 0)
                        throw new Exception("sound at " + rate + " Hz: expected " + RATE);
                    sound = new byte[bytes];
                    if (!ReadFully(input, sound))
                        sound = null;
                }
                else
                    break;   // the end (or something we don't know)
            }
            if (count == 0)
                throw new Exception("no frames");

            // The sound track, as long as the picture (silence if none came).
            int length = (int)((long)count * RATE / fps) * 4;
            if (sound == null || sound.Length < length)
            {
                byte[] full = new byte[length];
                if (sound != null)
                    Buffer.BlockCopy(sound, 0, full, 0, sound.Length);
                sound = full;
            }
            const int CHUNK = 1024 * 4;   // 1024 sample frames at a time
            for (int at = 0; at < length; at += CHUNK)
            {
                int n = Math.Min(CHUNK, length - at);
                byte[] part = new byte[n];
                Buffer.BlockCopy(sound, at, part, 0, n);
                long t = (long)(at / 4) * 10000000L / RATE;
                long d = (long)(n / 4) * 10000000L / RATE;
                Write(writer, audio, part, n, t, d);
            }
            Check(writer.DoFinalize(), "finalize");
            Marshal.ReleaseComObject(writer);
        }
        finally
        {
            MF.MFShutdown();
        }
        return count;
    }

    static void Write(IMFSinkWriter writer, int stream, byte[] bytes, int length, long time, long duration)
    {
        IMFMediaBuffer buffer;
        Check(MF.MFCreateMemoryBuffer(length, out buffer), "buffer");
        IntPtr data;
        int max, cur;
        Check(buffer.Lock(out data, out max, out cur), "lock");
        Marshal.Copy(bytes, 0, data, length);
        buffer.Unlock();
        buffer.SetCurrentLength(length);
        IMFSample sample;
        Check(MF.MFCreateSample(out sample), "sample");
        sample.AddBuffer(buffer);
        sample.SetSampleTime(time);
        sample.SetSampleDuration(duration);
        Check(writer.WriteSample(stream, sample), "write");
        Marshal.ReleaseComObject(sample);
        Marshal.ReleaseComObject(buffer);
    }

    static long Pack(int hi, int lo)
    {
        return ((long)hi << 32) | (uint)lo;
    }

    static void Check(int hr, string what)
    {
        if (hr < 0)
            throw new Exception(what + " failed (0x" + hr.ToString("X8") + ")");
    }

    static bool ReadFully(Stream s, byte[] buffer)
    {
        int got = 0;
        while (got < buffer.Length)
        {
            int n = s.Read(buffer, got, buffer.Length - got);
            if (n <= 0)
                return false;
            got += n;
        }
        return true;
    }

    // Godot gives RGBA; RGB32 is B, G, R, X in memory.
    static void RgbaToBgra(byte[] p)
    {
        for (int i = 0; i < p.Length; i += 4)
        {
            byte r = p[i];
            p[i] = p[i + 2];
            p[i + 2] = r;
        }
    }
}

static class MF
{
    public static readonly Guid MF_MT_MAJOR_TYPE = new Guid("48eba18e-f8c9-4687-bf11-0a74c9f96a8f");
    public static readonly Guid MF_MT_SUBTYPE = new Guid("f7e34c9a-42e8-4714-b74b-cb29d72c35e5");
    public static readonly Guid MF_MT_AVG_BITRATE = new Guid("20332624-fb0d-4d9e-bd0d-cbf6786c102e");
    public static readonly Guid MF_MT_INTERLACE_MODE = new Guid("e2724bb8-e676-4806-b4b2-a8d6efb44ccd");
    public static readonly Guid MF_MT_FRAME_SIZE = new Guid("1652c33d-d6b2-4012-b834-72030849a37d");
    public static readonly Guid MF_MT_FRAME_RATE = new Guid("c459a2e8-3d2c-4e44-b132-fee5156c7bb0");
    public static readonly Guid MF_MT_PIXEL_ASPECT_RATIO = new Guid("c6376a1e-8d0a-4027-be45-6d9a0ad39bb6");
    public static readonly Guid MF_MT_DEFAULT_STRIDE = new Guid("644b4e48-1e02-4516-b0eb-c01ca9d49ac6");
    public static readonly Guid MF_MT_MPEG2_PROFILE = new Guid("ad76a80b-2d5c-4e0b-b375-64e520137036");
    public static readonly Guid MFMediaType_Video = new Guid("73646976-0000-0010-8000-00AA00389B71");
    public static readonly Guid MFVideoFormat_H264 = new Guid("34363248-0000-0010-8000-00AA00389B71");
    public static readonly Guid MFVideoFormat_RGB32 = new Guid("00000016-0000-0010-8000-00AA00389B71");
    public static readonly Guid MF_MT_AUDIO_NUM_CHANNELS = new Guid("37e48bf5-645e-4c5b-89de-ada9e29b696a");
    public static readonly Guid MF_MT_AUDIO_SAMPLES_PER_SECOND = new Guid("5faeeae7-0290-4c31-9e8a-c534f68d9dba");
    public static readonly Guid MF_MT_AUDIO_AVG_BYTES_PER_SECOND = new Guid("1aab75c8-cfef-451c-ab95-ac034b8e1731");
    public static readonly Guid MF_MT_AUDIO_BLOCK_ALIGNMENT = new Guid("322de230-9eeb-43bd-ab7a-ff412251541d");
    public static readonly Guid MF_MT_AUDIO_BITS_PER_SAMPLE = new Guid("f2deb57f-40fa-4764-aa33-ed4f2d1ff669");
    public static readonly Guid MFMediaType_Audio = new Guid("73647561-0000-0010-8000-00AA00389B71");
    public static readonly Guid MFAudioFormat_AAC = new Guid("00001610-0000-0010-8000-00AA00389B71");
    public static readonly Guid MFAudioFormat_PCM = new Guid("00000001-0000-0010-8000-00AA00389B71");
    public static readonly Guid MF_READWRITE_ENABLE_HARDWARE_TRANSFORMS = new Guid("a634a91c-822b-41b9-a494-4de4643612b0");
    public static readonly Guid MF_SINK_WRITER_DISABLE_THROTTLING = new Guid("08b845d8-2b74-4afe-9d53-be16d2d5ae4f");

    [DllImport("mfplat.dll")] public static extern int MFStartup(int version, int flags);
    [DllImport("mfplat.dll")] public static extern int MFShutdown();
    [DllImport("mfplat.dll")] public static extern int MFCreateAttributes(out IMFAttributes attrs, int size);
    [DllImport("mfplat.dll")] public static extern int MFCreateMediaType(out IMFMediaType type);
    [DllImport("mfplat.dll")] public static extern int MFCreateSample(out IMFSample sample);
    [DllImport("mfplat.dll")] public static extern int MFCreateMemoryBuffer(int length, out IMFMediaBuffer buffer);
    [DllImport("mfreadwrite.dll", CharSet = CharSet.Unicode)]
    public static extern int MFCreateSinkWriterFromURL(string url, IntPtr byteStream, IMFAttributes attrs, out IMFSinkWriter writer);
}

// The COM interfaces, in vtable order. Only the methods used have real signatures; the
// others (Mxx) only keep their place.
[ComImport, Guid("2cd2d921-c447-44a7-a13c-4adabfc247e3"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMFAttributes
{
    void M01(); void M02(); void M03(); void M04(); void M05(); void M06(); void M07(); void M08();
    void M09(); void M10(); void M11(); void M12(); void M13(); void M14(); void M15(); void M16();
    void M17(); void M18();
    [PreserveSig] int SetUINT32([MarshalAs(UnmanagedType.LPStruct)] Guid key, int value);
    [PreserveSig] int SetUINT64([MarshalAs(UnmanagedType.LPStruct)] Guid key, long value);
    void M21();
    [PreserveSig] int SetGUID([MarshalAs(UnmanagedType.LPStruct)] Guid key, [MarshalAs(UnmanagedType.LPStruct)] Guid value);
    void M23(); void M24(); void M25(); void M26(); void M27(); void M28(); void M29(); void M30();
}

[ComImport, Guid("44ae0fa8-ea31-4109-8d2e-4cae4997c555"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMFMediaType
{
    void M01(); void M02(); void M03(); void M04(); void M05(); void M06(); void M07(); void M08();
    void M09(); void M10(); void M11(); void M12(); void M13(); void M14(); void M15(); void M16();
    void M17(); void M18();
    [PreserveSig] int SetUINT32([MarshalAs(UnmanagedType.LPStruct)] Guid key, int value);
    [PreserveSig] int SetUINT64([MarshalAs(UnmanagedType.LPStruct)] Guid key, long value);
    void M21();
    [PreserveSig] int SetGUID([MarshalAs(UnmanagedType.LPStruct)] Guid key, [MarshalAs(UnmanagedType.LPStruct)] Guid value);
    void M23(); void M24(); void M25(); void M26(); void M27(); void M28(); void M29(); void M30();
    void T1(); void T2(); void T3(); void T4(); void T5();
}

[ComImport, Guid("c40a00f2-b93a-4d80-ae8c-5a1c634f58e4"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMFSample
{
    void M01(); void M02(); void M03(); void M04(); void M05(); void M06(); void M07(); void M08();
    void M09(); void M10(); void M11(); void M12(); void M13(); void M14(); void M15(); void M16();
    void M17(); void M18(); void M19(); void M20(); void M21(); void M22(); void M23(); void M24();
    void M25(); void M26(); void M27(); void M28(); void M29(); void M30();
    void GetSampleFlags(); void SetSampleFlags(); void GetSampleTime();
    [PreserveSig] int SetSampleTime(long time);
    void GetSampleDuration();
    [PreserveSig] int SetSampleDuration(long duration);
    void GetBufferCount(); void GetBufferByIndex(); void ConvertToContiguousBuffer();
    [PreserveSig] int AddBuffer(IMFMediaBuffer buffer);
    void RemoveBufferByIndex(); void RemoveAllBuffers(); void GetTotalLength(); void CopyToBuffer();
}

[ComImport, Guid("045FA593-8799-42b8-BC8D-8968C6453507"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMFMediaBuffer
{
    [PreserveSig] int Lock(out IntPtr buffer, out int maxLength, out int currentLength);
    [PreserveSig] int Unlock();
    void GetCurrentLength();
    [PreserveSig] int SetCurrentLength(int length);
    void GetMaxLength();
}

[ComImport, Guid("3137f1cd-fe5e-4805-a5d8-fb477448cb3d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMFSinkWriter
{
    [PreserveSig] int AddStream(IMFMediaType type, out int index);
    [PreserveSig] int SetInputMediaType(int index, IMFMediaType type, IntPtr encodingParams);
    [PreserveSig] int BeginWriting();
    [PreserveSig] int WriteSample(int index, IMFSample sample);
    void SendStreamTick(); void PlaceMarker(); void NotifyEndOfSegment(); void Flush();
    [PreserveSig] int DoFinalize();
    void GetServiceForStream(); void GetStatistics();
}
