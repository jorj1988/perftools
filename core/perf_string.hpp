#pragma once
#include <array>
#include <atomic>
#include <algorithm>
#include <string>
#include "perf_allocator.hpp"

namespace perf
{

/// String classes used in perf API.
/// \ingroup CPP_API
using string = std::basic_string<char, std::char_traits<char>, detail::allocator<char>>;

namespace detail
{

template <std::size_t Size> class basic_short_string;

/// Find the maximum size a given string type can resize to.
inline std::size_t max_resize_size(string &)
  {
  return std::numeric_limits<std::size_t>::max();
  }

/// Find the maximum size a given string type can resize to.
template <std::size_t Size> std::size_t max_resize_size(basic_short_string<Size> &)
  {
  return Size-1;
  }

/// Append [t] to [str], with the string format [format]
template <typename StringType, typename T> void appendf(StringType &str, const T &t, const char *format)
  {
  auto old_size = str.size();
  std::size_t likely_required_size = 128;
  auto tmp_size = std::min(str.size() + likely_required_size, max_resize_size(str));
  str.resize(tmp_size);
  auto used =
#ifdef WIN32
    sprintf_s
#else
    snprintf
#endif
      (&str[0] + old_size, tmp_size - old_size, format, t);

  str.resize(old_size + used);
  }

/// Template wrapper for short strings, containing a fixed array of characters.
template <std::size_t Size> class basic_short_string
  {
public:
  basic_short_string()
    {
    m_data[0] = '\0';
    }

  basic_short_string(const char *data)
    : basic_short_string()
    {
    *this += data;
    }

  std::size_t capacity() const { return Size; }
  std::size_t size() const { return strlen(m_data.data()); }
  char *data() { return m_data.data(); }
  const char *data() const { return m_data.data(); }

  char &operator[](std::size_t i) { return m_data[i]; }

  void resize(std::size_t new_size)
    {
    check(new_size < Size);
    m_data[new_size] = '\0';
    }

  basic_short_string &operator+=(const char *t)
    {
    appendf(*this, t, "%s");
    return *this;
    }

  basic_short_string &operator+=(const basic_short_string &t)
    {
    appendf(*this, t.data(), "%s");
    return *this;
    }

private:
  std::array<char, Size> m_data;
  };

/// Wrapper type for a short string, used internally for string snippets.
using short_string = basic_short_string<64>;

template <typename StringType> void append(StringType &str, const char *t)
  {
  str += t;
  }

template <typename StringTypeA, typename StringTypeB> void append(StringTypeA &str, const StringTypeB &t)
  {
  str += t.data();
  }

template <typename StringType> void append(StringType &str, unsigned long long t)
  {
  appendf(str, t, "%llu");
  }

template <typename StringType> void append(StringType &str, unsigned long t)
  {
  appendf(str, t, "%lu");
  }

template <typename StringType, typename Type> void append(StringType &str, const std::atomic<Type> &t)
  {
  append(str, t.load());
  }

template <typename StringType, typename... Args, typename T> void append(StringType &str, const T &t, Args &&...args)
  {
  append(str, t);
  append(str, std::forward<Args>(args)...);
  }

}

}
