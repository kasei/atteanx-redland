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
  while (n_args--)
    PUSHs(va_arg(ap, SV *));
  va_end(ap);

  PUTBACK;

  count = call_method("new", G_SCALAR);

  if (count != 1)
    croak("Big trouble");

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
//     fprintf(stderr, "pushing argument for callback...\n");
    PUSHs(va_arg(ap, SV *));
  }
  va_end(ap);

  PUTBACK;

  count = call_sv(closure, G_DISCARD | G_VOID);

  if (count != 0)
    croak("Big trouble");

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
	switch (t->type) {
		case RAPTOR_TERM_TYPE_URI:
			value		= (char*) raptor_uri_as_string(t->value.uri);
//			fprintf(stderr, "raptor IRI: %s\n", value);
			return sv_2mortal(
				new_node_instance(aTHX_ newSVpvs("RDF::IRI"), 1,
					newSVpv(value, 0)
				)
			);
		case RAPTOR_TERM_TYPE_BLANK:
			value	= (char*) t->value.blank.string;
			return sv_2mortal(
				new_node_instance(aTHX_ newSVpvs("RDF::Blank"), 1,
					newSVpv(value, 0)
				)
			);
		case RAPTOR_TERM_TYPE_LITERAL:
			value		= (char*) t->value.literal.string;
			SV* class	= newSVpvs("RDF::Literal");
			if (t->value.literal.language) {
				return sv_2mortal(
					new_node_instance(aTHX_ class, 4,
						newSVpvs("value"),
						newSVpv(value, 0),
						newSVpvs("language"),
						newSVpv((char*) t->value.literal.language, 0)
					)
				);
			} else if (t->value.literal.datatype) {
				return sv_2mortal(
					new_node_instance(aTHX_ class, 4,
						newSVpvs("value"),
						newSVpv(value, 0),
						newSVpvs("datatype"),
						newSVpv((char*) raptor_uri_as_string(t->value.literal.datatype), 0)
					)
				);
			} else {
				return sv_2mortal(
					new_node_instance(aTHX_ class, 4,
						newSVpvs("value"),
						newSVpv(value, 0),
						newSVpvs("datatype"),
						newSVpvs("http://www.w3.org/2001/XMLSchema#string")
					)
				);
			}
			break;
		default:
			fprintf(stderr, "*** unknown node type %d during import\n", t->type);
			return NULL;
	}
}

static void parser_handle_triple (void* user_data, raptor_statement* triple) {
	parser_ctx* ctx	= (parser_ctx*) user_data;
	SV* closure	= ctx->closure;
	
	SV* s	= raptor_term_to_object(triple->subject);
	SV* p	= raptor_term_to_object(triple->predicate);
	SV* o	= raptor_term_to_object(triple->object);
    SV* t	= new_node_instance(aTHX_ sv_2mortal(newSVpvs("RDF::Triple")), 3, s, p, o);
	
// 	fprintf(stderr, "Parsed: %p %p %p\n", triple->subject, triple->predicate, triple->object);
	call_triple_handler_cb(closure, 1, t);
	return;
}

#define new_instance(klass)  S_new_instance(aTHX_ klass)
#define attach_struct(obj, ptr)  S_attach_struct(aTHX_ obj, ptr)

MODULE = RDF::X::Parser::Redland  PACKAGE = RDF::X::Parser::Redland::RaptorWorld  PREFIX = raptorworld_

PROTOTYPES: DISABLE

BOOT:
{
  HV *stash = gv_stashpvs("RDF::X::Parser::Redland", 0);
}

void
new (klass)
    SV *klass
  PREINIT:
    raptor_world *world;
  PPCODE:
  	if (!(world = raptor_new_world())) {
      croak("foo");
    }
// 	fprintf(stderr, "new raptor world: %p\n", world);
    XPUSHs(attach_struct(new_instance(gv_stashsv(klass, 0)), world));

void
DESTROY (raptor_world *world)
    CODE:
//       fprintf(stderr, "destroying raptor world: %p\n", world);
      raptor_free_world(world);

MODULE = RDF::X::Parser::Redland  PACKAGE = RDF::X::Parser::Redland  PREFIX = raptor_parser_

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
//       fprintf(stderr, "destroying raptor parser: %p\n", parser);
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
