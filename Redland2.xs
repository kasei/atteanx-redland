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

void
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

typedef struct {
	SV* closure;
} parser_ctx;

SV*
raptor_term_to_object(raptor_term* t) {
	char* value				= NULL;
	SV* object;
	SV* class;
	switch (t->type) {
		case RAPTOR_TERM_TYPE_URI:
			value	= (char*) raptor_uri_as_string(t->value.uri);
			class	= newSVpvs("RDF::Redland2::IRI");
			object	= new_node_instance(aTHX_ class, 0);
			SvREFCNT_dec(class);
			xs_object_magic_attach_struct(aTHX_ SvRV(object), t);
			return sv_2mortal(object);
		case RAPTOR_TERM_TYPE_BLANK:
			value	= (char*) t->value.blank.string;
			class	= newSVpvs("RDF::Redland2::Blank");
			object	= new_node_instance(aTHX_ class, 0);
			SvREFCNT_dec(class);
			xs_object_magic_attach_struct(aTHX_ SvRV(object), t);
			return sv_2mortal(object);
		case RAPTOR_TERM_TYPE_LITERAL:
			class	= newSVpvs("RDF::Redland2::Literal");
			object	= new_node_instance(aTHX_ class, 0);
			SvREFCNT_dec(class);
			xs_object_magic_attach_struct(aTHX_ SvRV(object), t);
			return sv_2mortal(object);
		default:
			fprintf(stderr, "*** unknown node type %d during import\n", t->type);
			return &PL_sv_undef;
	}
}

static void parser_handle_triple (void* user_data, raptor_statement* triple) {
	parser_ctx* ctx = (parser_ctx*) user_data;
	SV* closure = ctx->closure;
	
	SV* s	= raptor_term_to_object(triple->subject);
	SV* p	= raptor_term_to_object(triple->predicate);
	SV* o	= raptor_term_to_object(triple->object);
	SV* class	= newSVpvs("Attean::Triple");
	SV* t	= new_node_instance(aTHX_ class, 3, s, p, o);
	SvREFCNT_dec(class);
	
//	fprintf(stderr, "Parsed: %p %p %p\n", triple->subject, triple->predicate, triple->object);
	call_triple_handler_cb(closure, 1, t);
	return;
}

#define new_instance(klass)	 S_new_instance(aTHX_ klass)
#define attach_struct(obj, ptr)	 S_attach_struct(aTHX_ obj, ptr)

MODULE = RDF::Redland2	PACKAGE = AtteanX::Parser::Redland::RaptorWorld	 PREFIX = raptorworld_

PROTOTYPES: DISABLE

BOOT:
{
	HV *stash = gv_stashpvs("AtteanX::Parser::Redland", 0);
}

void
new (SV *klass)
	PREINIT:
		raptor_world *world;
	PPCODE:
		if (!(world = raptor_new_world())) {
			croak("foo");
		}
//		fprintf(stderr, "new raptor world: %p\n", world);
		XPUSHs(attach_struct(new_instance(gv_stashsv(klass, 0)), world));

void
DESTROY (raptor_world *world)
	CODE:
//		 fprintf(stderr, "destroying raptor world: %p\n", world);
	  raptor_free_world(world);

MODULE = RDF::Redland2	PACKAGE = AtteanX::Parser::Redland	PREFIX = raptor_parser_

PROTOTYPES: DISABLE

void raptor_parser_build_struct (SV* self, raptor_world* world, char* name)
	PREINIT:
		raptor_parser *parser;
	CODE:
		if (!(parser = raptor_new_parser(world, name))) {
			croak("foo");
		}
//		fprintf(stderr, "new raptor parser: %p\n", parser);
		xs_object_magic_attach_struct(aTHX_ SvRV(self), parser);

void
DESTROY (raptor_parser *parser)
	CODE:
//		 fprintf(stderr, "destroying raptor parser: %p\n", parser);
	  raptor_free_parser(parser);

SV*
raptor_parser_header (raptor_parser *parser)
	PREINIT:
	  const char* header;
	CODE:
		header = raptor_parser_get_accept_header(parser);
		RETVAL = newSVpv(header, 0);
		raptor_free_memory((void*)header);
	OUTPUT:
		RETVAL

void
_parse (raptor_parser *parser, char* buffer, const char* base_uri, SV* closure)
	PREINIT:
		raptor_world *world;
		raptor_uri *base;
		parser_ctx ctx;
	CODE:
		ctx.closure = closure;
		world = raptor_parser_get_world(parser);
		base = raptor_new_uri(world, (const unsigned char *) base_uri);
		raptor_parser_set_statement_handler(parser, &ctx, parser_handle_triple);
		raptor_parser_parse_start(parser, base);
		raptor_parser_parse_chunk(parser, (const unsigned char *) buffer, strlen(buffer), 1);

MODULE = RDF::Redland2 PACKAGE = RDF::Redland2::IRI PREFIX = raptor_term_iri_

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

MODULE = RDF::Redland2 PACKAGE = RDF::Redland2::Blank PREFIX = raptor_term_blank_

SV*
raptor_term_blank_value (raptor_term* term)
	PREINIT:
		unsigned char* string;
	CODE:
		string = term->value.blank.string;
		RETVAL = newSVpv((const char*) string, 0);
	OUTPUT:
		RETVAL

MODULE = RDF::Redland2 PACKAGE = RDF::Redland2::Literal PREFIX = raptor_term_literal_

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
