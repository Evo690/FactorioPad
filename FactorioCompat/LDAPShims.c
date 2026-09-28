#include <stdint.h>
#include <stddef.h>


#define EXPORT \
    __attribute__((visibility("default"))) \
    __attribute__((used))


EXPORT void ber_free(void) {}

EXPORT
char *ldap_err2string(void)
{
    static char message[] =
        "LDAP unsupported on iPadOS";

    return message;
}


EXPORT void *ldap_first_attribute(void) { return NULL; }
EXPORT void *ldap_first_entry(void)     { return NULL; }

EXPORT void ldap_free_urldesc(void) {}

EXPORT char *ldap_get_dn(void)          { return NULL; }
EXPORT void *ldap_get_values_len(void)  { return NULL; }

EXPORT void *ldap_init(void)            { return NULL; }

EXPORT void ldap_memfree(void)          {}
EXPORT int ldap_msgfree(void)           { return 0; }

EXPORT void *ldap_next_attribute(void)  { return NULL; }
EXPORT void *ldap_next_entry(void)      { return NULL; }

EXPORT int ldap_search_s(void)          { return -1; }
EXPORT int ldap_set_option(void)        { return -1; }
EXPORT int ldap_simple_bind_s(void)     { return -1; }
EXPORT int ldap_unbind_s(void)          { return 0; }
EXPORT int ldap_url_parse(void)         { return -1; }

EXPORT void ldap_value_free_len(void)   {}
