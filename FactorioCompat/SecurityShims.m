#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

#include <stdint.h>


#define EXPORT \
    __attribute__((visibility("default"))) \
    __attribute__((used))


/*
 * Use our own ABI-compatible typedefs.
 *
 * The iPhoneOS SDK does not expose these macOS APIs.
 * Avoid dependencies on missing declarations such as
 * SecKeychainRef and SecItemImportExportKeyParameters.
 */

typedef int32_t  FactorioOSStatus;
typedef int32_t  FactorioSecExternalFormat;
typedef int32_t  FactorioSecExternalItemType;
typedef uint32_t FactorioSecItemImportExportFlags;


/*
 * Security error codes.
 */

static const FactorioOSStatus FactorioErrSecUnimplemented = -4;
static const FactorioOSStatus FactorioErrSecItemNotFound  = -25300;


#pragma mark - SecCertificateCopyLongDescription


/*
 * macOS:
 *
 * CFStringRef SecCertificateCopyLongDescription(
 *     CFAllocatorRef alloc,
 *     SecCertificateRef certificate,
 *     CFErrorRef *error
 * );
 *
 * The returned CFString follows the Create Rule.
 */

EXPORT
CFStringRef SecCertificateCopyLongDescription(
    CFAllocatorRef allocator,
    CFTypeRef certificate,
    CFErrorRef *error
)
{
    if (error) {
        *error = NULL;
    }

    /*
     * The certificate object's description is enough for diagnostics.
     * CFCopyDescription returns a retained object.
     */

    if (certificate) {
        return CFCopyDescription(certificate);
    }

    CFAllocatorRef actualAllocator =
        allocator ? allocator : kCFAllocatorDefault;

    return CFStringCreateCopy(
        actualAllocator,
        CFSTR("Certificate")
    );
}


#pragma mark - SecIdentityCreateWithCertificate


/*
 * macOS:
 *
 * OSStatus SecIdentityCreateWithCertificate(
 *     CFTypeRef keychainOrArray,
 *     SecCertificateRef certificate,
 *     SecIdentityRef *identity
 * );
 *
 * iPadOS does not provide this function.
 *
 * For now, behave as if the system found no private key
 * that matches the certificate.
 */

EXPORT
FactorioOSStatus SecIdentityCreateWithCertificate(
    CFTypeRef keychainOrArray,
    CFTypeRef certificate,
    CFTypeRef *identity
)
{
    (void)keychainOrArray;
    (void)certificate;

    if (identity) {
        *identity = NULL;
    }

    return FactorioErrSecItemNotFound;
}


#pragma mark - SecItemImport


/*
 * ABI macOS:
 *
 * OSStatus SecItemImport(
 *     CFDataRef importedData,
 *     CFStringRef fileNameOrExtension,
 *     SecExternalFormat *inputFormat,
 *     SecExternalItemType *itemType,
 *     SecItemImportExportFlags flags,
 *     const SecItemImportExportKeyParameters *keyParams,
 *     SecKeychainRef importKeychain,
 *     CFArrayRef *outItems
 * );
 *
 * In this ABI:
 * - the first two arguments are pointers
 * - inputFormat/itemType are pointers to 32-bit enums
 * - flags is 32-bit
 * - the last three arguments are pointers
 */

EXPORT
FactorioOSStatus SecItemImport(
    CFDataRef importedData,
    CFStringRef fileNameOrExtension,
    FactorioSecExternalFormat *inputFormat,
    FactorioSecExternalItemType *itemType,
    FactorioSecItemImportExportFlags flags,
    const void *keyParams,
    CFTypeRef importKeychain,
    CFArrayRef *outItems
)
{
    (void)importedData;
    (void)fileNameOrExtension;
    (void)inputFormat;
    (void)itemType;
    (void)flags;
    (void)keyParams;
    (void)importKeychain;

    if (outItems) {
        *outItems = NULL;
    }

    return FactorioErrSecUnimplemented;
}
