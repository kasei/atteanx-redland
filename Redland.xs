#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <stdio.h>

#include "xs_object_magic.h"

#include <raptor2.h>

static SV *
S_new_instance (pTHX_ HV *klass)
{
	SV *obj, *self;

	obj = (SV *)newHV();
	self = newRV_noinc(obj);
	sv_bless(self, klass);

	return self;
}

static SV *
S_attach_struct (pTHX_ SV *obj, void *ptr)
{
	xs_object_magic_attach_struct(aTHX_ SvRV(obj), ptr);
	return obj;
}

static SV *
new_node_instance (pTHX_ SV *klass, UV n_args, ...)
{
	int count;
	va_list ap;
	SV *ret;
	dSP;

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	EXTEND(SP, n_args + 1);
	PUSHs(klass);

	va_start(ap, n_args);
	while (n_args--) {
		PUSHs(va_arg(ap, SV *));
	}
	va_end(ap);

	PUTBACK;

	count = call_method("new", G_SCALAR);

	if (count != 1) {
		croak("Big trouble");
	}

	SPAGAIN;
	ret = POPs;
	SvREFCNT_inc(ret);

	FREETMPS;
	LEAVE;

	return ret;
}

static void
call_triple_handler_cb (pTHX_ SV *closure, UV n_args, ...)
{
	int count;
	va_list ap;
	SV *ret;
	dSP;

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	EXTEND(SP, n_args);

	va_start(ap, n_args);
	while (n_args--) {
// 		fprintf(stderr, "pushing argument for callback...\n");
		PUSHs(va_arg(ap, SV *));
	}
	va_end(ap);

	PUTBACK;

	count = call_sv(closure, G_DISCARD | G_VOID);

	if (count != 0) {
		croak("Big trouble");
	}

	SPAGAIN;

	FREETMPS;
	LEAVE;
}

static SV*
raptor_term_to_object(raptor_term* t) {
	char* value				= NULL;
	SV* object;
	SV* class;
	switch (t->type) {
		case RAPTOR_TERM_TYPE_URI:
			value	= (char*) raptor_uri_as_string(t->value.uri);
			class	= newSVpvs("AtteanX::Redland::IRI");
			object	= new_node_instance(aTHX_ class, 0);
			SvREFCNT_dec(class);
			xs_object_magic_attach_struct(aTHX_ SvRV(object), t);
			return object;
		case RAPTOR_TERM_TYPE_BLANK:
			value	= (char*) t->value.blank.string;
			class	= newSVpvs("AtteanX::Redland::Blank");
			object	= new_node_instance(aTHX_ class, 0);
			SvREFCNT_dec(class);
			xs_object_magic_attach_struct(aTHX_ SvRV(object), t);
			return object;
		case RAPTOR_TERM_TYPE_LITERAL:
			class	= newSVpvs("AtteanX::Redland::Literal");
			object	= new_node_instance(aTHX_ class, 0);
			SvREFCNT_dec(class);
			xs_object_magic_attach_struct(aTHX_ SvRV(object), t);
			return object;
		default:
			fprintf(stderr, "*** unknown node type %d during import\n", t->type);
			return &PL_sv_undef;
	}
}

static void
parser_handle_triple (void* user_data, raptor_statement* triple) {
	SV* closure = (SV*) user_data;
	
	SV* s	= raptor_term_to_object(triple->subject);
	SV* p	= raptor_term_to_object(triple->predicate);
	SV* o	= raptor_term_to_object(triple->object);
	SV* class	= newSVpvs("Attean::Triple");
	SV* t	= new_node_instance(aTHX_ class, 3, s, p, o);
	SvREFCNT_dec(class);
	SvREFCNT_dec(s);
	SvREFCNT_dec(p);
	SvREFCNT_dec(o);
	
//	fprintf(stderr, "Parsed: %p %p %p\n", triple->subject, triple->predicate, triple->object);
	call_triple_handler_cb(closure, 1, t);
	SvREFCNT_dec(t);
	return;
}

#define new_instance(klass)	 S_new_instance(aTHX_ klass)
#define attach_struct(obj, ptr)	 S_attach_struct(aTHX_ obj, ptr)

MODULE = AtteanX::Redland	PACKAGE = AtteanX::Parser::Redland::RaptorWorld	 PREFIX = raptorworld_

PROTOTYPES: DISABLE

BOOT:
{
	HV *stash = gv_stashpvs("AtteanX::Parser::Redland", 0);
}

void
raptorworld_new (SV *klass)
	PREINIT:
		raptor_world *world;
	PPCODE:
		if (!(world = raptor_new_world())) {
			croak("foo");
		}
		if (raptor_world_open(world)) {
			croak("foo");
		}
//		fprintf(stderr, "new raptor world: %p\n", world);
		XPUSHs(attach_struct(new_instance(gv_stashsv(klass, 0)), world));

void
raptorworld_DESTROY (raptor_world *world)
	CODE:
//		 fprintf(stderr, "destroying raptor world: %p\n", world);
	  raptor_free_world(world);

MODULE = AtteanX::Redland	PACKAGE = AtteanX::Parser::Redland	PREFIX = raptor_parser_

PROTOTYPES: DISABLE

void
raptor_parser_build_struct (SV* self, raptor_world* world, char* name)
	PREINIT:
		raptor_parser *parser;
	CODE:
		if (!(parser = raptor_new_parser(world, name))) {
			croak("foo");
		}
//		fprintf(stderr, "new raptor parser: %p\n", parser);
		xs_object_magic_attach_struct(aTHX_ SvRV(self), parser);

void
raptor_parser_DESTROY (raptor_parser *parser)
	CODE:
//		 fprintf(stderr, "destroying raptor parser: %p\n", parser);
	  raptor_free_parser(parser);

SV*
raptor_parser_media_types(SV* self)
	PREINIT:
		int i, j;
		raptor_world *world;
		raptor_parser* parser;
		const raptor_syntax_description* desc;
		AV* array;
	CODE:
		array = newAV();
		if (sv_isobject(self)) {
			parser = xs_object_magic_get_struct_rv(aTHX_ self);
			desc	= raptor_parser_get_description(parser);
			fprintf(stderr, "Parser Accept: %s\n", raptor_parser_get_accept_header(parser));
			for (i = 0; i < desc->mime_types_count; i++) {
				const raptor_type_q qt	= desc->mime_types[i];
				const char* type	= qt.mime_type;
				unsigned char q		= qt.q;
//				fprintf(stderr, "-> %s (%d)\n", type, (int) q);
				if (q == 10) {
					av_push(array, newSVpv(qt.mime_type, qt.mime_type_len));
				}
			}
		} else {
			i = 0;
			if ((world = raptor_new_world())) {
				if (raptor_world_open(world)) {
					croak("foo");
				}
				desc	= raptor_world_get_parser_description(world, i++);
				while (desc != NULL) {
					for (j = 0; j < desc->mime_types_count; j++) {
						const raptor_type_q qt	= desc->mime_types[j];
						const char* type	= qt.mime_type;
						unsigned char q		= qt.q;
//						fprintf(stderr, "-> %s (%d)\n", type, (int) q);
						if (q == 10) {
							av_push(array, newSVpv(qt.mime_type, qt.mime_type_len));
						}
					}
					desc	= raptor_world_get_parser_description(world, i++);
				}
				raptor_free_world(world);
			} else {
				fprintf(stderr, "failed to construct temporary raptor world object\n");
			}
		}
		RETVAL = newRV((SV *)array);
	OUTPUT:
		RETVAL

SV*
raptor_parser_canonical_media_type(SV* self)
	PREINIT:
		int i;
		raptor_world *world;
		raptor_parser* parser;
		const raptor_syntax_description* desc;
	CODE:
		RETVAL = &PL_sv_undef;
		if (sv_isobject(self)) {
			parser = xs_object_magic_get_struct_rv(aTHX_ self);
			desc	= raptor_parser_get_description(parser);
			for (i = 0; i < desc->mime_types_count; i++) {
				const raptor_type_q qt	= desc->mime_types[i];
				const char* type	= qt.mime_type;
				unsigned char q		= qt.q;
				if (q == 10) {
					RETVAL = newSVpv(qt.mime_type, qt.mime_type_len);
					break;
				}
			}
		}
	OUTPUT:
		RETVAL

void
raptor_parser__parse (raptor_parser *parser, char* buffer, const char* base_uri, SV* closure)
	PREINIT:
		raptor_world *world;
		raptor_uri *base;
	CODE:
		world = raptor_parser_get_world(parser);
		base = raptor_new_uri(world, (const unsigned char *) base_uri);
		raptor_parser_set_statement_handler(parser, closure, parser_handle_triple);
		raptor_parser_parse_start(parser, base);
		raptor_parser_parse_chunk(parser, (const unsigned char *) buffer, strlen(buffer), 1);

void
raptor_parser_parse_begin (raptor_parser *parser, const char* base_uri, SV* closure)
	PREINIT:
		raptor_world *world;
		raptor_uri *base;
	CODE:
		world = raptor_parser_get_world(parser);
		base = raptor_new_uri(world, (const unsigned char *) base_uri);
		raptor_parser_set_statement_handler(parser, closure, parser_handle_triple);
		raptor_parser_parse_start(parser, base);

void
raptor_parser_parse_continue (raptor_parser *parser, char* buffer, int finished)
	CODE:
		raptor_parser_parse_chunk(parser, (const unsigned char *) buffer, strlen(buffer), finished);

MODULE = AtteanX::Redland PACKAGE = AtteanX::Redland::IRI PREFIX = raptor_term_iri_

SV*
raptor_term_iri_value (raptor_term* term)
	PREINIT:
		raptor_uri* uri;
		unsigned char* string;
	CODE:
		uri = term->value.uri;
		string = raptor_uri_as_string(uri);
		RETVAL = newSVpv((const char*) string, 0);
	OUTPUT:
		RETVAL

MODULE = AtteanX::Redland PACKAGE = AtteanX::Redland::Blank PREFIX = raptor_term_blank_

SV*
raptor_term_blank_value (raptor_term* term)
	PREINIT:
		unsigned char* string;
	CODE:
		string = term->value.blank.string;
		RETVAL = newSVpv((const char*) string, 0);
	OUTPUT:
		RETVAL

MODULE = AtteanX::Redland PACKAGE = AtteanX::Redland::Literal PREFIX = raptor_term_literal_

SV*
raptor_term_literal_value (raptor_term* term)
	PREINIT:
		raptor_term_literal_value literal;
	CODE:
		literal = term->value.literal;
		RETVAL = newSVpv((const char*) literal.string, 0);
	OUTPUT:
		RETVAL

SV*
raptor_term_literal_language (raptor_term* term)
	PREINIT:
		raptor_term_literal_value literal;
	CODE:
		literal = term->value.literal;
		if (literal.language) {
			RETVAL = newSVpv((const char*) literal.language, 0);
		} else {
			RETVAL = &PL_sv_undef;
		}		
	OUTPUT:
		RETVAL

SV*
raptor_term_literal_datatype (raptor_term* term)
	PREINIT:
		raptor_term_literal_value literal;
	CODE:
		literal = term->value.literal;
		if (literal.datatype) {
			const unsigned char* string = raptor_uri_as_string(literal.datatype);
			SV* class	= newSVpvs("Attean::IRI");
			SV* value	= newSVpv((const char*) string, 0);
			RETVAL = new_node_instance(aTHX_ class, 1, value);
			SvREFCNT_dec(value);
			SvREFCNT_dec(class);
		} else {
			RETVAL = &PL_sv_undef;
		}		
	OUTPUT:
		RETVAL
