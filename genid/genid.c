#include <Windows.h>
#include <stdio.h>
#include <stdint.h>

static void mystrcpy(wchar_t *dst, wchar_t *src, size_t n) {
    while (n > 0) {
        n--;
      if (!(*dst++ = *src++))
        break;
    }
    *dst = 0;
}

uint16_t jd_crc16(const void* data, uint32_t size) {
  const uint8_t* ptr = (const uint8_t*)data;
  uint16_t crc = 0xffff;
  while (size--) {
    uint8_t data = *ptr++;
    uint8_t x = (crc >> 8) ^ data;
    x ^= x >> 4;
    crc = (crc << 8) ^ (x << 12) ^ (x << 5) ^ x;
  }
  return crc;
}

int wmain(int argc, TCHAR* argv[], TCHAR* envp[]) {
  HCRYPTPROV hCryptProv;
  BYTE pbData[10] = {0};

  wchar_t localfile[_MAX_PATH + 30] = {0};
  mystrcpy(localfile, argv[0], _MAX_PATH);
  wchar_t* lastslash = NULL;
  for (wchar_t* p = localfile; *p; p++) {
    if (*p == '\\')
      lastslash = p;
  }
  if (lastslash)
    mystrcpy(lastslash, L"\\rolling.txt", 20);
  else
    mystrcpy(localfile, L"rolling.txt", 20);

  FILE* fp;

  if (_wfopen_s(&fp, localfile, L"wt") || !fp) {
    printf("can't open rolling.txt\n");
    return 1;
  }

  UINT index;
  BOOL f_Ok = FALSE;
  if (argc == 2) {
    if (_wcsnicmp(argv[1], L"0x", 2) == 0)
      f_Ok = swscanf_s(argv[1] + 2, L"%X", &index) == 1;
    else
      f_Ok = swscanf_s(argv[1], L"%d", &index) == 1;
  }

  if (!f_Ok) {
    printf("needs index arg\n");
    return 1;
  }

  if (CryptAcquireContext(
          &hCryptProv, NULL,
          (LPCWSTR)L"Microsoft Base Cryptographic Provider v1.0", PROV_RSA_FULL,
          CRYPT_VERIFYCONTEXT)) {
    if (CryptGenRandom(hCryptProv, sizeof(pbData), pbData)) {
      CryptReleaseContext(hCryptProv, 0);
    } else {
      CryptReleaseContext(hCryptProv, 0);
      printf("Error during CryptGenRandom.\n");
      return 1;
    }
  } else {
    printf("Error during CryptAcquireContext!\n");
    return 1;
  }

  fprintf(fp, "Index=0x%X\n", index);
  int i;
  for (i = 2; i < sizeof(pbData); ++i) {
    fprintf(fp, "0x%02x ", pbData[i]);
    printf("%02x ", pbData[i]);
  }
  fprintf(fp, "\n");
  printf("\n");

  pbData[1] = 0;
  for (i = 4; i <= 0xc; i += 4) {
    pbData[0] = i;
    uint16_t crc = jd_crc16(pbData, sizeof(pbData));
    fprintf(fp, "0x%02x 0x%02x ", crc & 0xff, crc >> 8);
  }

  fprintf(fp, "\n");
  fclose(fp);

  printf("device ID generated OK\n");

  return 0;
}