#ifndef Libsoratun_h
#define Libsoratun_h

#include <stdlib.h>

/// SORACOM Arc 経由で SORACOM Unified Endpoint に HTTP リクエストを送信します。
///
/// @param configJson SORACOM Arc 設定 JSON 文字列 (arc.json の内容)
/// @param method HTTP メソッド ("GET" または "POST")
/// @param path リクエストパス
/// @param body リクエストボディ
/// @return レスポンスボディの C 文字列 (呼び出し元が free する必要があります)、エラー時は NULL
extern char* Send(const char* configJson, const char* method, const char* path, const char* body);

/// SORACOM Arc 経由で SORACOM Unified Endpoint に UDP メッセージを送信します。
///
/// @param configJson SORACOM Arc 設定 JSON 文字列 (arc.json の内容)
/// @param body リクエストボディ
/// @param bodyLen ボディのバイト長
/// @param port 送信先ポート番号
/// @param timeout タイムアウト (秒)
/// @return レスポンスの C 文字列 (呼び出し元が free する必要があります)、エラー時は NULL
extern char* SendUDP(const char* configJson, const char* body, int bodyLen, int port, int timeout);

#endif /* Libsoratun_h */
