#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#include <cstring>
#include "dobby.h"

uintptr_t getUnitySlide() {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "UnityFramework")) {
            return _dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0;
}

void (*old_SaveParam)(void *instance);
void new_SaveParam(void *instance) {
    if (instance != nullptr) {
        *(int *)((uintptr_t)instance + 0x28) = 999999;
    }
    old_SaveParam(instance);
}

void (*old_showGold)(void *instance);
void new_showGold(void *instance) {
    if (instance != nullptr) {
        void *gmanaj = *(void **)((uintptr_t)instance + 0x240);
        if (gmanaj != nullptr) {
            *(int *)((uintptr_t)gmanaj + 0x28) = 999999;
        }
    }
    old_showGold(instance);
}

void (*old_LoadInterstitial)(void *instance);
void new_LoadInterstitial(void *instance) {
    return;
}

void (*old_InitAd)(void *instance);
void new_InitAd(void *instance) {
    return;
}

void (*old_activateAd)(void *instance);
void new_activateAd(void *instance) {
    if (instance != nullptr) {
        *(bool *)((uintptr_t)instance + 0x169) = false;
    }
}

__attribute__((constructor))
static void initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        uintptr_t slide = getUnitySlide();
        if (slide == 0) return;

        DobbyHook((void *)(slide + 0x2FF4668), (void *)new_SaveParam, (void **)&old_SaveParam);
        DobbyHook((void *)(slide + 0x30354D8), (void *)new_showGold, (void **)&old_showGold);

        DobbyHook((void *)(slide + 0x2F74E44), (void *)new_LoadInterstitial, (void **)&old_LoadInterstitial);
        DobbyHook((void *)(slide + 0x2F787A0), (void *)new_InitAd, (void **)&old_InitAd);
        DobbyHook((void *)(slide + 0x2FF25BC), (void *)new_activateAd, (void **)&old_activateAd);
    });
}
