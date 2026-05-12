# Test documentation

## Build commands to build debug builds

### Thread Sanitizer

```bash
# Linux
sudo ./runner.sh --host=linux --arch=x86_64 --enable-base --gpl --kit --test=thread --build-debug --skip -y -f

# Windows - note that windows build will need windows libtsan libraries which are not available by defauly on linux
sudo ./runner.sh --host=windows --arch=x86_64 --enable-base --gpl --kit --test=thread --build-debug --skip -y -f
```

### Address Sanitizer

```bash
# Linux
sudo ./runner.sh --host=linux --arch=x86_64 --enable-base --gpl --kit --test=address --build-debug --skip -y -f

# Windows - note that windows build will need windows libasan libraries which are not available by defauly on linux
sudo ./runner.sh --host=windows --arch=x86_64 --enable-base --gpl --kit --test=address --build-debug --skip -y -f
```

### Undefined Behavior Sanitizer

```bash
# Linux
sudo ./runner.sh --host=linux --arch=x86_64 --enable-base --gpl --kit --test=undefined --build-debug --skip -y -f

# Windows - note that windows build will need windows libubsan libraries which are not available by defauly on linux
sudo ./runner.sh --host=windows --arch=x86_64 --enable-base --gpl --kit --test=undefined --build-debug --skip -y -f
```

## Test execution Commands

### Thread Sanitizer

```bash
# disbale ASLR temporarily for thread sanitizer tests
setarch $(uname -m) -R ./FFmpegKit/build/tests/ffmpegkit_tests > test_tsan.log 2>&1
```

### Address Sanitizer

```bash
export LSAN_OPTIONS=suppressions=/home/vscode/ffmpeg-kit-builders/FFmpegKit/tests/asan.supp && export ASAN_OPTIONS=detect_odr_violation=0:detect_leaks=1 && ./FFmpegKit/build/tests/ffmpegkit_tests > test_asan.log 2>&1
```

