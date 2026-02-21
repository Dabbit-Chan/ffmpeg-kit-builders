# Test documentation

## Build commands to build debug builds

### Thread Sanitizer

```bash
# Linux
sudo ./runner.sh --host=linux --arch=x86_64 --enable-base --gpl --kit --test --build-debug --skip --skip-pkg-check -y -f --cflags="-fsanitize=thread" --ldflags="-fsanitize=thread"

# Windows - note that windows build will need windows libtsan libraries which are not available by defauly on linux
sudo ./runner.sh --host=windows --arch=x86_64 --enable-base --gpl --kit --test --build-debug --skip --skip-pkg-check -y -f --cflags="-fsanitize=thread" --ldflags="-fsanitize=thread"
```

### Address Sanitizer

```bash
# Linux
sudo ./runner.sh --host=linux --arch=x86_64 --enable-base --gpl --kit --test --build-debug --skip --skip-pkg-check -y -f --cflags="-fsanitize=address" --ldflags="-fsanitize=address"

# Windows - note that windows build will need windows libasan libraries which are not available by defauly on linux
sudo ./runner.sh --host=windows --arch=x86_64 --enable-base --gpl --kit --test --build-debug --skip --skip-pkg-check -y -f --cflags="-fsanitize=address" --ldflags="-fsanitize=address"
```

### Undefined Behavior Sanitizer

```bash
# Linux
sudo ./runner.sh --host=linux --arch=x86_64 --enable-base --gpl --kit --test --build-debug --skip --skip-pkg-check -y -f --cflags="-fsanitize=undefined" --ldflags="-fsanitize=undefined"

# Windows - note that windows build will need windows libubsan libraries which are not available by defauly on linux
sudo ./runner.sh --host=windows --arch=x86_64 --enable-base --gpl --kit --test --build-debug --skip --skip-pkg-check -y -f --cflags="-fsanitize=undefined" --ldflags="-fsanitize=undefined"
```

## Test execution Commands

### Thread Sanitizer

```bash
# disbale ASLR temporarily for thread sanitizer tests
setarch $(uname -m) -R ./desktop/build/tests/ffmpegkit_tests > test_tsan.log 2>&1
```

### Address Sanitizer

```bash
export LSAN_OPTIONS=suppressions=/home/vscode/ffmpeg-kit-builders/desktop/tests/asan.supp && export ASAN_OPTIONS=detect_odr_violation=0:detect_leaks=1 && ./desktop/build/tests/ffmpegkit_tests > test_asan.log 2>&1
```
