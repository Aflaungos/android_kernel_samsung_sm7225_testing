# SPDX-License-Identifier: GPL-2.0

# chacha is used by the /dev/random driver which is always builtin
obj-y						+= chacha.o
obj-$(CONFIG_CRYPTO_LIB_CHACHA_GENERIC)		+= libchacha.o

obj-$(CONFIG_CRYPTO_LIB_POLY1305_GENERIC)	+= libpoly1305.o
libpoly1305-y					:= poly1305-donna32.o
libpoly1305-$(CONFIG_ARCH_SUPPORTS_INT128)	:= poly1305-donna64.o
libpoly1305-y					+= poly1305.o

# blake2s is used by the /dev/random driver which is always builtin
obj-y						+= libblake2s.o
libblake2s-y					:= blake2s.o
libblake2s-$(CONFIG_CRYPTO_LIB_BLAKE2S_GENERIC)	+= blake2s-generic.o

ifneq ($(CONFIG_CRYPTO_MANAGER_DISABLE_TESTS),y)
libblake2s-y					+= blake2s-selftest.o
endif
