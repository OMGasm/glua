import std.mem as mem;
import std.string as string;
import std.ptr as ptr;
import type.leb128;
import type.fmt;
import type.magic;
import std.limits as limits;
import std.sys as sys;

using ULEB = type::uLEB128;
using UString = string::SizedString<ULEB>;

using Header;
using Compat;
using Op;
using Opcode;
using Proto;
using ProtoHead;
using ProtoData;
using is_debug;
using KGC;
using KNum;

bool dbg;

struct Header {
    // lj_bcdump.h
    type::Magic<"\x1BLJ"> head;
    u8 version; // >= 0x80 == private implementation modifications
    Compat cf;
    if(is_debug(cf)) UString name;
};

bitfield CompatFlags {
    BE      : 1;
    STRIP   : 1;
    FFI     : 1;
    FR2     : 1;
};

enum CompatFlags2 : ULEB {
    //what?
    KNOWN         = 0x0F,
    DETERMINISTIC = 0x800000000000,
};

union Compat {
    CompatFlags flags;
    CompatFlags2 f;
};

fn is_debug(Compat c) {
    dbg = !c.flags.STRIP;
    return dbg;
};

struct Proto {
    ULEB length;
    ProtoData data;
};

bitfield ProtoFlags {
    has_child_proto     : 1;
    is_vararg           : 1;
    FFI_uses_kcdata     : 1;
    jit_disabled        : 1;
    bc_patched_iloop    : 1; // 0x10
    has_return          : 1; //"already emitted"
    needs_fixup_return  : 1; // 0x40
};

struct ProtoHeader {
    ProtoFlags flags;
    u8 nparams;
    u8 framesize;
    u8 nupvalues;
    ULEB numkgc;    //collectables
    ULEB numkn;     //numbers
    ULEB numbc;

    if(dbg) {
        ULEB debuglen;
        if(debuglen) {
            ULEB firstline;
            ULEB numlines;
        }
    }
};

struct ProtoData {
    ProtoHeader head;
    Op inst[head.numbc];
    u16 uvdata[head.nupvalues];
    KGC gc[head.numkgc];
    KNum nums[head.numkn];
    
    if(dbg) {
        char debug[head.debuglen];
    }
};

struct Op {
    Opcode code;//[[name("code_"+string::to_string(($ - addressof(parent.parent.block_len)) / 4 + 1))]];
    u8 vals[3][[hidden]];
};

enum Opcode : u8 {
    // comparison
    ISLT    = 0x00,ISGE,ISLE,ISGT,
    ISEQV   = 0x04,ISNEV,ISEQS,
    ISNES   = 0x07,ISEQN,ISNEN,ISEQP,ISNEP,
    //unary test + copy
    ISTC    = 0x0C,ISFC,IST,ISF,ISTYPE,ISNUM,
    //unary
    MOV     = 0x12,NOT,UNM,LEN,
    //binary
    ADDVN   = 0x16,SUBVN,MULVV,DIVVN,MODVN,
    ADDNV   = 0x1B,SUBNV,MULNV,DIVNV,MODNV,
    ADDVV   = 0x20,SUBVV,MULVV,DIVVV,MODVV,
    POW     = 0x25,CAT,    //meow
    //constant
    KSTR    = 0x27,KCDATA,KSHORT,KNUM,KPRI,KNIL,
    //upvalue and function
    UGET    = 0x2D,USETV,USETS,USETN,USETP,UCLO,FNEW,
    //table
    TNEW     = 0x34,TDUP,GGET,GSET,TGETV,TGETS,TGETB,TGETR,TSETV,TSETS,TSETB,TSETM,TSETR,
    //calls and vararg. [T]ail
    CALLM   = 0x41,CALL,CALLMT,CALLT,ITERC,ITERN,VARG,ISNEXT,
    //returns
    RETM    = 0x49,RET,RET0,RET1,
    //loops, branches. [I]nterpret/[J]it, [I]nit/[C]all/[L]oop
    FORI    = 0x4D,JFORI,
    FORL    = 0x4F,IFORL,JFORL,
    ITERL   = 0x52,IITERL,JITERL,
    LOOP    = 0x55,ILOOP,JLOOP,
    JMP     = 0x58,
    //func headers. [I]nterpret/[J]it, [F]ixarg/[V]ararg/[C] func
    FUNCF   = 0x59,IFUNCF,JFUNCF,FUNCV,IFUNCV,JFUNCV,FUNCC,FUNCCW,
};

enum KTV : ULEB {
    NIL,
    FALSE,
    TRUE,
    INT,
    NUM,
    STR_Z,
    STR = KTV::STR_Z ... limits::u128_max(),
};

enum KT : ULEB {
    CHILD,
    TABLE,
    INT,
    UINT,
    COMPLEX,
    STR_Z,
    STR = KT::STR_Z ... limits::u128_max(),
};

struct KStr<auto O, auto N> {
    char val[u128(N) - O];
};

struct KNum {
    ULEB lo;
    if(lo&1)ULEB hi;
};

struct Complex {
    KNum lo, hi;
};

struct KTVal {
    KTV type;
    
    match(type) {
        (KTV::NIL): {}
        (KTV::FALSE): bool val[[no_unique_address]];
        (KTV::TRUE): bool val[[no_unique_address]];
        (KTV::INT): KNum val;
        (KTV::NUM): KNum val;
        (_): KStr<KTV::STR, type> val [[inline]];
    }
};

struct KHash {
    KTVal hash[2];
};

struct KTab {
    ULEB n_arr, n_hash;
    KTVal arr[n_arr];
    KHash hash[n_hash];
};

struct KGC {
    KT type;
    match(type) {
        (KT::CHILD): {
            sys::assert(parent.head.flags.has_child_proto, "unexpected child");
            ProtoHeader child;
        }
        (KT::TABLE): KTab table;
        (KT::INT): s64 num;
        (KT::UINT): u64 num;
        (KT::COMPLEX): Complex num;
        (_): KStr<KT::STR, type> val [[inline]];
    }
};

struct Dump {
    Header;
    Proto p[2];//while(std::mem::read_unsigned($, 1))];
};

Dump dump @ 0[[inline]];
ULEB len @ $;
ProtoData data @ $;