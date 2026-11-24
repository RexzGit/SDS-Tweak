cpp
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

        // ARM64 RET instruction (0xD65F03C0) to immediately block ad functions
        const uint32_t retPatch[] = { 0xD65F03C0 };
        patchBytes(slide + 0x2F74E44, retPatch, 1); // LoadInterstitial
        patchBytes(slide + 0x2F787A0, retPatch, 1); // InitAd
        patchBytes(slide + 0x2FF25BC, retPatch, 1); // activateAd

        // ARM64 patch for SaveParam: MOV W8, #0x423F; MOVK W8, #0x000F, LSL #16 (999999); STR W8, [X0, #0x28]; RET
        const uint32_t coinPatch[] = {
            0x528847E8, // mov w8, #0x423f
            0x72A001E8, // movk w8, #0xf, lsl #16 (w8 = 999999)
            0xB9002808, // str w8, [x0, #0x28] (this->coins = 999999)
            0xD65F03C0  // ret
        };
        patchBytes(slide + 0x2FF4668, coinPatch, 4); // SaveParam
    });
}
