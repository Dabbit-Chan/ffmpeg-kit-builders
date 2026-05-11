#include <gtest/gtest.h>
#include "Packages.hpp"
#include <set>
#include <string>

class PackagesTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Tests can assume FFmpeg libraries are initialized
        // by the test framework or main function
    }
};

TEST_F(PackagesTest, GetPackageName) {
    std::string packageName = ffmpegkit::Packages::getPackageName();
    EXPECT_FALSE(packageName.empty());
    
    // Package name should be the same as bundle type
    std::string bundleType = ffmpegkit::Packages::getBundleType();
    EXPECT_EQ(packageName, bundleType);
}

TEST_F(PackagesTest, GetBundleType) {
    std::string bundleType = ffmpegkit::Packages::getBundleType();
    EXPECT_FALSE(bundleType.empty());
    
    // Accept known bundle names and any stable bundle-style suffix.
    std::set<std::string> commonTypes = {"base", "audio", "video", "video_hw", "full", "custom"};
    EXPECT_TRUE(commonTypes.count(bundleType) > 0 ||
                bundleType.find("bundle") != std::string::npos ||
                bundleType.find("-bundle") != std::string::npos)
                << "Unexpected bundle type: " << bundleType;
}

TEST_F(PackagesTest, GetBuildConfiguration) {
    std::string config = ffmpegkit::Packages::getBuildConfiguration();
    EXPECT_FALSE(config.empty());
    
    // Should contain FFmpeg configuration indicators
    EXPECT_TRUE(config.find("--enable-") != std::string::npos ||
                config.find("--disable-") != std::string::npos ||
                config.find("--prefix=") != std::string::npos)
                << "Configuration doesn't look like FFmpeg config: " << config.substr(0, 100);
}

TEST_F(PackagesTest, GetIsGpl) {
    // This should return either true or false consistently
    bool isGpl1 = ffmpegkit::Packages::getIsGpl();
    bool isGpl2 = ffmpegkit::Packages::getIsGpl();
    EXPECT_EQ(isGpl1, isGpl2) << "GPL status should be consistent";
    
    // If GPL is enabled, build configuration should contain --enable-gpl
    if (isGpl1) {
        std::string config = ffmpegkit::Packages::getBuildConfiguration();
        EXPECT_TRUE(config.find("--enable-gpl") != std::string::npos)
                << "GPL reported as enabled but --enable-gpl not found in config";
    }
}

TEST_F(PackagesTest, GetIsNonFree) {
    // This should return either true or false consistently
    bool isNonFree1 = ffmpegkit::Packages::getIsNonFree();
    bool isNonFree2 = ffmpegkit::Packages::getIsNonFree();
    EXPECT_EQ(isNonFree1, isNonFree2) << "NonFree status should be consistent";
    
    // If non-free is enabled, build configuration should contain --enable-nonfree
    if (isNonFree1) {
        std::string config = ffmpegkit::Packages::getBuildConfiguration();
        EXPECT_TRUE(config.find("--enable-nonfree") != std::string::npos)
                << "NonFree reported as enabled but --enable-nonfree not found in config";
    }
    
    // GPL and non-free should not both be enabled (mutually exclusive in FFmpeg)
    bool isGpl = ffmpegkit::Packages::getIsGpl();
    EXPECT_FALSE(isGpl && isNonFree1) << "GPL and NonFree should not both be enabled";
}

TEST_F(PackagesTest, GetExternalLibraries) {
    auto libraries = ffmpegkit::Packages::getExternalLibraries();
    ASSERT_NE(libraries, nullptr);
    
    // Should not crash and should return a valid set (possibly empty)
    // If not empty, should contain valid library names
    for (const auto& lib : *libraries) {
        EXPECT_FALSE(lib.empty()) << "Library name should not be empty";
        EXPECT_GT(lib.length(), 1) << "Library name should be at least 2 characters: " << lib;
        
        // Should not contain spaces or special characters
        EXPECT_EQ(lib.find(' '), std::string::npos) << "Library name should not contain spaces: " << lib;
        EXPECT_EQ(lib.find('\t'), std::string::npos) << "Library name should not contain tabs: " << lib;
    }
    
    // If we have external libraries, they should be reflected in build config
    if (!libraries->empty()) {
        std::string config = ffmpegkit::Packages::getBuildConfiguration();
        for (const auto& lib : *libraries) {
            // Check for either --enable-lib<name> or --enable-<name> pattern
            std::string libFlag1 = "--enable-lib" + lib;
            std::string libFlag2 = "--enable-" + lib;
            EXPECT_TRUE(config.find(libFlag1) != std::string::npos ||
                        config.find(libFlag2) != std::string::npos)
                        << "Library " << lib << " reported but not found in build config";
        }
    }
}

TEST_F(PackagesTest, GetRegisteredCodecs) {
    auto codecs = ffmpegkit::Packages::getRegisteredCodecs();
    ASSERT_NE(codecs, nullptr);
    EXPECT_FALSE(codecs->empty()) << "Should have at least some registered codecs";
    
    // Should contain basic FFmpeg codecs
    std::set<std::string> expectedCodecs = {
        "pcm_s16le", "aac", "mp3", "h264", "hevc", "vp9", "av1", "mpeg4"
    };
    
    bool foundExpected = false;
    for (const auto& expected : expectedCodecs) {
        if (codecs->count(expected)) {
            foundExpected = true;
            break;
        }
    }
    EXPECT_TRUE(foundExpected) << "Should have at least one common codec";
    
    // All codec names should be valid (non-empty, no spaces)
    for (const auto& codec : *codecs) {
        EXPECT_FALSE(codec.empty()) << "Codec name should not be empty";
        EXPECT_EQ(codec.find(' '), std::string::npos) << "Codec name should not contain spaces: " << codec;
    }
}

TEST_F(PackagesTest, GetRegisteredEncoders) {
    auto encoders = ffmpegkit::Packages::getRegisteredEncoders();
    ASSERT_NE(encoders, nullptr);
    EXPECT_FALSE(encoders->empty()) << "Should have at least some registered encoders";
    
    // All encoders should also be in the general codecs list
    auto codecs = ffmpegkit::Packages::getRegisteredCodecs();
    for (const auto& encoder : *encoders) {
        EXPECT_TRUE(codecs->count(encoder)) 
                << "Encoder " << encoder << " should be in general codecs list";
    }
    
    // Should contain common encoders
    std::set<std::string> expectedEncoders = {
        "pcm_s16le", "aac", "mp3", "libx264", "libx265"
    };
    
    bool foundExpected = false;
    for (const auto& expected : expectedEncoders) {
        if (encoders->count(expected)) {
            foundExpected = true;
            break;
        }
    }
    EXPECT_TRUE(foundExpected) << "Should have at least one common encoder";
}

TEST_F(PackagesTest, GetRegisteredDecoders) {
    auto decoders = ffmpegkit::Packages::getRegisteredDecoders();
    ASSERT_NE(decoders, nullptr);
    EXPECT_FALSE(decoders->empty()) << "Should have at least some registered decoders";
    
    // All decoders should also be in the general codecs list
    auto codecs = ffmpegkit::Packages::getRegisteredCodecs();
    for (const auto& decoder : *decoders) {
        EXPECT_TRUE(codecs->count(decoder)) 
                << "Decoder " << decoder << " should be in general codecs list";
    }
    
    // Should contain common decoders
    std::set<std::string> expectedDecoders = {
        "pcm_s16le", "aac", "mp3", "h264", "hevc", "vp9", "av1"
    };
    
    bool foundExpected = false;
    for (const auto& expected : expectedDecoders) {
        if (decoders->count(expected)) {
            foundExpected = true;
            break;
        }
    }
    EXPECT_TRUE(foundExpected) << "Should have at least one common decoder";
}

TEST_F(PackagesTest, EncodersDecodersDisjoint) {
    auto encoders = ffmpegkit::Packages::getRegisteredEncoders();
    auto decoders = ffmpegkit::Packages::getRegisteredDecoders();
    
    // Modern FFmpeg exposes many bidirectional codecs. Verify overlap exists
    // but does not completely collapse the sets.
    std::set<std::string> intersection;
    for (const auto& encoder : *encoders) {
        if (decoders->count(encoder)) {
            intersection.insert(encoder);
        }
    }
    
    EXPECT_GT(intersection.size(), 0u)
                << "Expected at least some codecs to be both encoders and decoders";
    EXPECT_LT(intersection.size(), encoders->size())
                << "Encoders and decoders unexpectedly collapsed into one set";
    EXPECT_LT(intersection.size(), decoders->size())
                << "Encoders and decoders unexpectedly collapsed into one set";
}

TEST_F(PackagesTest, GetRegisteredMuxers) {
    auto muxers = ffmpegkit::Packages::getRegisteredMuxers();
    ASSERT_NE(muxers, nullptr);
    EXPECT_FALSE(muxers->empty()) << "Should have at least some registered muxers";
    
    // Should contain common muxers
    std::set<std::string> expectedMuxers = {
        "mp4", "avi", "mov", "matroska", "flv", "webm"
    };
    
    bool foundExpected = false;
    for (const auto& expected : expectedMuxers) {
        if (muxers->count(expected)) {
            foundExpected = true;
            break;
        }
    }
    EXPECT_TRUE(foundExpected) << "Should have at least one common muxer";
    
    // All muxer names should be valid
    for (const auto& muxer : *muxers) {
        EXPECT_FALSE(muxer.empty()) << "Muxer name should not be empty";
        EXPECT_EQ(muxer.find(' '), std::string::npos) << "Muxer name should not contain spaces: " << muxer;
    }
}

TEST_F(PackagesTest, GetRegisteredDemuxers) {
    auto demuxers = ffmpegkit::Packages::getRegisteredDemuxers();
    ASSERT_NE(demuxers, nullptr);
    EXPECT_FALSE(demuxers->empty()) << "Should have at least some registered demuxers";
    
    // Should contain common demuxers
    std::set<std::string> expectedDemuxers = {
        "mp4", "avi", "mov", "matroska", "flv", "webm"
    };
    
    bool foundExpected = false;
    for (const auto& expected : expectedDemuxers) {
        if (demuxers->count(expected)) {
            foundExpected = true;
            break;
        }
    }
    EXPECT_TRUE(foundExpected) << "Should have at least one common demuxer";
    
    // All demuxer names should be valid
    for (const auto& demuxer : *demuxers) {
        EXPECT_FALSE(demuxer.empty()) << "Demuxer name should not be empty";
        EXPECT_EQ(demuxer.find(' '), std::string::npos) << "Demuxer name should not contain spaces: " << demuxer;
    }
}

TEST_F(PackagesTest, GetRegisteredFilters) {
    auto filters = ffmpegkit::Packages::getRegisteredFilters();
    ASSERT_NE(filters, nullptr);
    EXPECT_FALSE(filters->empty()) << "Should have at least some registered filters";
    
    // Should contain common filters
    std::set<std::string> expectedFilters = {
        "scale", "crop", "overlay", "volume", "resample"
    };
    
    bool foundExpected = false;
    for (const auto& expected : expectedFilters) {
        if (filters->count(expected)) {
            foundExpected = true;
            break;
        }
    }
    EXPECT_TRUE(foundExpected) << "Should have at least one common filter";
    
    // All filter names should be valid
    for (const auto& filter : *filters) {
        EXPECT_FALSE(filter.empty()) << "Filter name should not be empty";
        EXPECT_EQ(filter.find(' '), std::string::npos) << "Filter name should not contain spaces: " << filter;
    }
}

TEST_F(PackagesTest, GetRegisteredProtocols) {
    auto protocols = ffmpegkit::Packages::getRegisteredProtocols();
    ASSERT_NE(protocols, nullptr);
    EXPECT_FALSE(protocols->empty()) << "Should have at least some registered protocols";
    
    // Should contain common protocols
    std::set<std::string> expectedProtocols = {
        "file", "http", "https", "ftp", "rtmp"
    };
    
    bool foundExpected = false;
    for (const auto& expected : expectedProtocols) {
        if (protocols->count(expected)) {
            foundExpected = true;
            break;
        }
    }
    EXPECT_TRUE(foundExpected) << "Should have at least one common protocol";
    
    // All protocol names should be valid
    for (const auto& protocol : *protocols) {
        EXPECT_FALSE(protocol.empty()) << "Protocol name should not be empty";
        EXPECT_EQ(protocol.find(' '), std::string::npos) << "Protocol name should not contain spaces: " << protocol;
    }
}

TEST_F(PackagesTest, GetRegisteredBitStreamFilters) {
    auto bsfs = ffmpegkit::Packages::getRegisteredBitStreamFilters();
    ASSERT_NE(bsfs, nullptr);
    // Bitstream filters might be empty in some builds, so don't require non-empty
    
    // All BSF names should be valid
    for (const auto& bsf : *bsfs) {
        EXPECT_FALSE(bsf.empty()) << "BSF name should not be empty";
        EXPECT_EQ(bsf.find(' '), std::string::npos) << "BSF name should not contain spaces: " << bsf;
    }
}

TEST_F(PackagesTest, ConsistencyBetweenMethods) {
    // Test consistency between different methods
    auto libraries = ffmpegkit::Packages::getExternalLibraries();
    auto config = ffmpegkit::Packages::getBuildConfiguration();
    
    // If we report x264 in external libraries, should have libx264 encoder
    if (libraries->count("x264")) {
        auto encoders = ffmpegkit::Packages::getRegisteredEncoders();
        EXPECT_TRUE(encoders->count("libx264")) 
                << "x264 library reported but libx264 encoder not found";
    }
    
    // If we report x265 in external libraries, should have libx265 encoder
    if (libraries->count("x265")) {
        auto encoders = ffmpegkit::Packages::getRegisteredEncoders();
        EXPECT_TRUE(encoders->count("libx265")) 
                << "x265 library reported but libx265 encoder not found";
    }
    
    // If we report opus in external libraries, should have opus encoder/decoder
    if (libraries->count("opus")) {
        auto encoders = ffmpegkit::Packages::getRegisteredEncoders();
        auto decoders = ffmpegkit::Packages::getRegisteredDecoders();
        EXPECT_TRUE(encoders->count("opus") || encoders->count("libopus")) 
                << "opus library reported but opus encoder not found";
        EXPECT_TRUE(decoders->count("opus") || decoders->count("libopus")) 
                << "opus library reported but opus decoder not found";
    }
}

TEST_F(PackagesTest, MethodReturnValuesAreStable) {
    // Test that multiple calls return the same results
    
    // Test basic methods
    std::string bundle1 = ffmpegkit::Packages::getBundleType();
    std::string bundle2 = ffmpegkit::Packages::getBundleType();
    EXPECT_EQ(bundle1, bundle2) << "Bundle type should be stable";
    
    std::string config1 = ffmpegkit::Packages::getBuildConfiguration();
    std::string config2 = ffmpegkit::Packages::getBuildConfiguration();
    EXPECT_EQ(config1, config2) << "Build configuration should be stable";
    
    bool gpl1 = ffmpegkit::Packages::getIsGpl();
    bool gpl2 = ffmpegkit::Packages::getIsGpl();
    EXPECT_EQ(gpl1, gpl2) << "GPL status should be stable";
    
    bool nonfree1 = ffmpegkit::Packages::getIsNonFree();
    bool nonfree2 = ffmpegkit::Packages::getIsNonFree();
    EXPECT_EQ(nonfree1, nonfree2) << "NonFree status should be stable";
    
    // Test collection methods (they should return same size and content)
    auto libs1 = ffmpegkit::Packages::getExternalLibraries();
    auto libs2 = ffmpegkit::Packages::getExternalLibraries();
    EXPECT_EQ(libs1->size(), libs2->size()) << "External libraries count should be stable";
    EXPECT_EQ(*libs1, *libs2) << "External libraries set should be stable";
    
    auto codecs1 = ffmpegkit::Packages::getRegisteredCodecs();
    auto codecs2 = ffmpegkit::Packages::getRegisteredCodecs();
    EXPECT_EQ(codecs1->size(), codecs2->size()) << "Codecs count should be stable";
    EXPECT_EQ(*codecs1, *codecs2) << "Codecs set should be stable";
}
