package model

import (
	"database/sql/driver"
	"fmt"
	"reflect"
	"strconv"
	"strings"
)

// Scalar 是 PostgreSQL 数组列支持的元素类型。
type Scalar interface {
	~int | ~int8 | ~int16 | ~int32 | ~int64 | ~string
}

// Array 对应 PostgreSQL 的数组列（如 BIGINT[]、TEXT[]），Go 侧是切片。
//
//	GORM 字段：Ancestors Array[int64] `gorm:"column:ancestors;type:bigint[]"`
//
// 数据库中以标准数组字面量（如 {0,1,3}）保存，字符串元素按需加双引号。
// pgx 的 database/sql 包装通常以字符串返回数组，Scan 也兼容切片输入。
type Array[T Scalar] []T

// Scan 实现 sql.Scanner。pgx 的 database/sql 包装以文本形式返回数组。
func (a *Array[T]) Scan(src any) error {
	switch v := src.(type) {
	case nil:
		*a = nil
		return nil
	case string:
		return a.parse(v)
	case []byte:
		return a.parse(string(v))
	default:
		return fmt.Errorf("model.Array: unsupported scan type %T", src)
	}
}

// Value 实现 driver.Valuer，输出 PostgreSQL 数组字面量；nil 写为空数组。
func (a Array[T]) Value() (driver.Value, error) {
	var b strings.Builder
	b.WriteByte('{')
	for i, v := range a {
		if i > 0 {
			b.WriteByte(',')
		}
		b.WriteString(encodeElement(v))
	}
	b.WriteByte('}')
	return b.String(), nil
}

// rawElement 记录元素的原始文本，quoted 表示在数组字面量中带引号（保留首尾空格）。
type rawElement struct {
	text   string
	quoted bool
}

// parse 解析 {0,1,3} / {"a,b","c"} 形式的数组字面量。
func (a *Array[T]) parse(s string) error {
	s = strings.TrimSpace(s)
	if s == "" || s == "{}" {
		*a = Array[T]{}
		return nil
	}
	if len(s) < 2 || s[0] != '{' || s[len(s)-1] != '}' {
		return fmt.Errorf("model.Array: invalid array literal %q", s)
	}

	var (
		elems    []rawElement
		cur      strings.Builder
		inQuote  bool
		escaped  bool
		wasQuote bool
	)
	for _, r := range s[1 : len(s)-1] {
		switch {
		case escaped:
			cur.WriteRune(r)
			escaped = false
		case r == '\\' && inQuote:
			escaped = true
		case r == '"':
			inQuote = !inQuote
			wasQuote = true
		case r == ',' && !inQuote:
			elems = append(elems, rawElement{cur.String(), wasQuote})
			cur.Reset()
			wasQuote = false
		default:
			cur.WriteRune(r)
		}
	}
	if inQuote {
		return fmt.Errorf("model.Array: unterminated quote in %q", s)
	}
	elems = append(elems, rawElement{cur.String(), wasQuote})

	out := make(Array[T], 0, len(elems))
	for _, e := range elems {
		text := e.text
		if !e.quoted {
			text = strings.TrimSpace(text)
		}
		v, err := parseElement[T](text)
		if err != nil {
			return fmt.Errorf("model.Array: invalid element %q: %w", e.text, err)
		}
		out = append(out, v)
	}
	*a = out
	return nil
}

func parseElement[T Scalar](s string) (T, error) {
	var v T
	rv := reflect.ValueOf(&v).Elem()
	switch rv.Kind() {
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		n, err := strconv.ParseInt(s, 10, rv.Type().Bits())
		if err != nil {
			return v, err
		}
		rv.SetInt(n)
	case reflect.String:
		rv.SetString(s)
	default:
		return v, fmt.Errorf("unsupported element kind %s", rv.Kind())
	}
	return v, nil
}

func encodeElement[T Scalar](v T) string {
	rv := reflect.ValueOf(v)
	switch rv.Kind() {
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return strconv.FormatInt(rv.Int(), 10)
	case reflect.String:
		return quoteElement(rv.String())
	default:
		return fmt.Sprint(v)
	}
}

// quoteElement 始终给字符串元素加双引号，并转义反斜杠与双引号。
func quoteElement(s string) string {
	return `"` + strings.NewReplacer(`\`, `\\`, `"`, `\"`).Replace(s) + `"`
}
