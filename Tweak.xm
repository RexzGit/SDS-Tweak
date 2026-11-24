#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#include <cstring>
#include <cstdint>

extern "C" kern_return_t mach_vm_protect(vm_map_t, mach_vm_address_t, mach_vm_size_t, boolean_t, vm_prot_t);

uintptr_t getUnitySlide() {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "UnityFramework")) {
            return _dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0;
}

void patchBytes(uintptr_t address, const uint32_t *instructions, size_t count) {
    size_t size = count * sizeof(uint32_t);
    mach_vm_protect(mach_task_self(), (mach_vm_address_t)address, size, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    memcpy((void *)address, instructions, size);
    mach_vm_protect(mach_task_self(), (mach_vm_address_t)address, size, false, VM_PROT_READ | VM_PROT_EXECUTE);
}

__attribute__((constructor))
static void initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        uintptr_t slide = getUnitySlide();
        if (slide == 0) return;

        const uint32_t retPatch[] = { 0xD65F03C0 };
        patchBytes(slide + 0x2F74E44, retPatch, 1);
        patchBytes(slide + 0x2F787A0, retPatch, 1);
        patchBytes(slide + 0x2FF25BC, retPatch, 1);

        const uint32_t coinPatch[] = {
            0x528847E8,
            0x72A001E8,
            0xB9002808,
            0xD65F03C0
        };
        patchBytes(slide + 0x2FF4668, coinPatch, 4);
    });
}
