// -----------------------------------------------------------------
// File:   TSyntaxFileEditor.cc
// Author: (c) 2023, 2024 Jens Kallup - paule32
// All rights reserved
//
// only for education, and non-profit usage !
//
// @brief This file provides a very simple Syntax Highlighter for
//        TurboVision C++. Based on TFileEditor. We have to change
//        the member "formatLine" to "virtual" in source header
//        file: editors.hpp.
//        The tokens for the syntax can be easily store into the:
//
//        std::map< std::string, TColorAttr > EditorSyntaxToken;
// -----------------------------------------------------------------
# include "TSyntaxFileEditor.h"

// -----------------------------------------------------------------
// std::vector is a simple way, to search for enum class items ...
// -----------------------------------------------------------------
std::vector< TSyntaxLanguageType > TSyntaxType;
std::vector< TSyntaxCommentType  > TSyntaxComment;

// -----------------------------------------------------------------
// this map holds the possible token's for the Pasccal DSL.
// It will be used, if "TSyntaxType" contains:
// "TSyntaxLanguageType::pascal"
// -----------------------------------------------------------------
std::map< std::string, TColorAttr > SyntaxPascalToken =
{
    { "program",        0x1e },    // 0x1f = blue on white
    
    { "array",          0x1e },
    { "begin",          0x1e },
    { "byte",           0x1e },
    { "case",           0x1e },
    { "char",           0x1e },
    { "class",          0x1e },
    { "do",             0x1e },
    { "dec",            0x1e },
    { "else",           0x1e },
    { "end",            0x1e },
    { "for",            0x1e },
    { "if",             0x1e },
    { "implementation", 0x1e },
    { "inc",            0x1e },
    { "integer",        0x1e },
    { "interface",      0x1e },
    { "of",             0x1e },
    { "record",         0x1e },
    { "string",         0x1e },
    { "then",           0x1e },
    { "unit",           0x1e },
    { "until",          0x1e },
    { "uses",           0x1e },
    { "while",          0x1e },
    { "word",           0x1e }
};

// -----------------------------------------------------------------
// editor for syntax highligter, based on:  TEditor <-- TFileEdior
// -----------------------------------------------------------------
TSyntaxFileEditor::TSyntaxFileEditor(
    const TRect  & bounds,
    TScrollBar   * hScrollBar,
    TScrollBar   * vScrollBar,
    TIndicator   * indicator,
    TStringView    filename):
    TFileEditor( bounds,hScrollBar,vScrollBar,indicator,filename) {

    // ----------------------------------------------
    // standard pascal token color map ...
    // ----------------------------------------------
    EditorSyntaxToken = SyntaxPascalToken;
    EditorSelectedColor = 0x0f;

    // for get word under cursor
    eventMask |= evBroadcast;
    
    // ----------------------------------------------
    // no selected text at begin of construction
    // ----------------------------------------------
    selected = false;
}
    
// -------------------------------
// event handler ...
// -------------------------------
void TSyntaxFileEditor::handleEvent( TEvent &event )
{
    static int pos, flag = 0;
    char   Ch;
    
    if (event.what == evKeyDown)
    {
        if (event.keyDown.keyCode == kbLeft) {
            if ((event.keyDown.controlKeyState == 0x310)
            ||  (event.keyDown.controlKeyState == 0x330)
            ||  (event.keyDown.controlKeyState == 0x390)
            ||  (event.keyDown.controlKeyState == 0x110)
            ||  (event.keyDown.controlKeyState == 0x130)
            ||  (event.keyDown.controlKeyState == 0x190)) {
                clearEvent(event);
                
                selecting = true;
                selected  = true;

                if ((cursor.x < 1) && (cursor.y == 1)) {
                    cursor.x = 1;
                }
                
                if (pos < 1) {
                    cursor.x = 1;
                    pos = 1;
                    return;
                }
                
                Ch = bufChar(--pos);
                
                if (Ch == '\n' || Ch == '\r') {
                    pos = pos - 2;
                    Ch  = bufChar(pos);
                    
                    cursor.y = cursor.y - 1;
                    setCursor(cursor.x, cursor.y);
                    
                    int  l = 1;
                    for (l = 1; l < 2048; ++l) {
                        if ((bufChar( l ) == '\n')
                        ||  (bufChar( l ) == '\r'))
                        break;
                    }
                    
                    cursor.x = l;
                    setCursor(cursor.x, cursor.y);
                }
                
                selStart  = cursor.x - 1;
                selEnd    = cursor.x    ;
                
                //TColorAttr Color = { 0xffff00, 0x008000 };
                uchar Color = 0x0f;
                writeChar(cursor.x-1, cursor.y, Ch, Color, 1);
                
                setCursor(cursor.x-1, cursor.y);
                return;
            }
        }   else
        if (event.keyDown.keyCode == kbRight) {
            if ((event.keyDown.controlKeyState == 0x310)
            ||  (event.keyDown.controlKeyState == 0x330)
            ||  (event.keyDown.controlKeyState == 0x390)
            ||  (event.keyDown.controlKeyState == 0x110)
            ||  (event.keyDown.controlKeyState == 0x130)
            ||  (event.keyDown.controlKeyState == 0x190)) {
                clearEvent(event);

                if (flag == 0) {
                    pos  = cursor.x;
                    flag = 1;
                }

                if (pos >= bufLen)
                return;

                Ch = bufChar(pos++);
                
                if (Ch == '\n' || Ch == '\r') {
                    Ch  = bufChar(pos+1);
                    pos = pos + 2;
                    
                    cursor.x = 0;
                    cursor.y = cursor.y + 1;
                    setCursor(cursor.x, cursor.y);
                }
                
                selecting = true;
                selected  = true;

                selStart  = cursor.x    ;
                selEnd    = cursor.x + 1;
   
                //TColorAttr Color = { 0xffff00, 0x008000 };
                uchar Color = 0x0f;
                writeChar(cursor.x, cursor.y, Ch, Color, 1);
                
                setCursor(cursor.x + 1, cursor.y);
                return;
            }
        }   else
        if (event.keyDown.keyCode == kbCtrlS) {
            clearEvent(event);
            messageBox("ctrl + s",mfInformation|mfOKButton);
            return;
        }
    }

    TFileEditor::handleEvent( event );
}

// -----------------------------------------------------
// this is our "syntax highlight" member function ...
// -----------------------------------------------------
void TSyntaxFileEditor::formatLine(
    TScreenCell *DrawBuf,
    uint P,
    int Width,
    TAttrPair Colors
    ) {
        
    TSpan<TScreenCell> Cells(DrawBuf, Width);
    TStringView chars;
    TColorAttr  Color;
    std::string token;
    
    bool tokenIsComment = false;
    
    int  pos;
    char Ch;
    
    int X = 0;
    int Y = 0;

    Color = EditorTextColor;
    token = "";
    
    while (1) {
        if (P >= bufLen || X >= Width) break;
        tokenIsComment = false;
        chars = bufChars(P);
        
        Color = EditorTextColor;
        Ch    = chars[0];
        
        // ----------------------------
        // parse white space's ...
        // ----------------------------
        if (Ch == ' ') {
            while (X < Width) {
                Color = EditorTextColor;

                ::setCell(Cells[X], Ch, Color);
                X++;
                P++;
                chars = bufChars(P);
                Ch = chars[0];
                if (Ch != ' ') break;
            }
        }
        
        // ----------------------------
        // parse token for Pascal DSL
        // ----------------------------
        if (((Ch >= 'A') && (Ch <= 'Z'))
        ||  ((Ch >= 'a') && (Ch <= 'z'))) {
            pos = X;
            Color = EditorTextColor;

            ::setCell(Cells[X++], Ch, Color);
            token.push_back(Ch);
            while (1) {
                if ((P >= bufLen) || (X >= Width)) break;
                P++;
                chars = bufChars(P);
                Ch = chars[0];
                if (((Ch >= 'A') && (Ch <= 'Z'))
                ||  ((Ch >= 'a') && (Ch <= 'z'))
                ||  ((Ch >= '0') && (Ch <= '9'))
                ||  (Ch == '_')) {
                    Color = EditorTextColor;
                    
                    ::setCell(Cells[X++], Ch, Color);
                    token.push_back(Ch);
                }   else break;
            }
            if (X >= Width) break;
            
            // ---------------------------------------------
            // convert token letter's to lower case letter's
            // ---------------------------------------------
            for (char &c : token)
            c = std::tolower(c);
            X = pos;
        
            auto it = EditorSyntaxToken.find(token);
            if (it != EditorSyntaxToken.end()) {
                for (char &c: token) {
                    Color = it->second;
                    if (X >= Width) break;
                    ::setCell(Cells[X++], c, Color);
                }
            }   else {
                for (char &c: token) {
                    if (X >= Width) break;
                    Color = EditorTextColor;
                
                    ::setCell(Cells[X++], c, Color);
                }
            }
            token = "";
        }
        
        // ----------------------------
        // parse comment's ...
        // ----------------------------
        if (Ch == '&') {
            Color = EditorTextColor;

            ::setCell(Cells[X], '&', Color);
            X++;
            P++;
            chars = bufChars(P);
            Ch = chars[0];
            if (P >= bufLen || X >= Width) break;
            
            // ----------------------------
            // dBase comment &&
            // ----------------------------
            if (Ch == '&') {
                tokenIsComment = true;
                Color = EditorCommentColor;
            
                ::setCell(Cells[X-1], Ch, Color);
                if (X < Width) {
                    do  {
                        ::setCell(Cells[X++], Ch, Color);
                        P++;
                        chars = bufChars(P);
                        Ch = chars[0];
                        if (Ch == '\r' || Ch == '\n') {
                            while (X < Width)
                            ::setCell(Cells[X++], ' ', Color);
                            P++;
                            break;
                        }
                    }   while (X < Width);
                    ++P;
                }   else break;
            }   else
            if (Ch == '\r' || Ch == '\n') {
                Color = EditorCommentColor;
            
                while (X < Width)
                ::setCell(Cells[X++], ' ', Color);
                P++;
                break;
            }   else {
                Color = EditorTextColor;
            
                ::setCell(Cells[X], Ch, Color);
                X++;
                P++;
                if (P >= bufLen || X >= Width) break;
            }
        }   else
        if (Ch == '/') {
            Color = EditorTextColor;
        
            ::setCell(Cells[X], '/', Color);
            X++;
            P++;
            chars = bufChars(P);
            Ch = chars[0];
            if (P >= bufLen || X >= Width) break;
            
            // ----------------------------
            // c++ comment
            // ----------------------------
            if (Ch == '/') {
                tokenIsComment = true;
                Color = EditorCommentColor;
            
                ::setCell(Cells[X-1], Ch, Color);
                if (X < Width) {
                    do  {
                        ::setCell(Cells[X++], Ch, Color);
                        P++;
                        chars = bufChars(P);
                        Ch = chars[0];
                        if (Ch == '\r' || Ch == '\n') {
                            while (X < Width)
                            ::setCell(Cells[X++], ' ', Color);
                            P++;
                            break;
                        }
                    }   while (X < Width);
                    ++P;
                }   else break;
            }   else
                
            // ----------------------------
            // c comment
            // ----------------------------
            if (Ch == '*') {
                tokenIsComment = true;
                Color = EditorCommentColor;

                ::setCell(Cells[X-1], '/', Color);
                ::setCell(Cells[X  ], '*', Color);
                X++;
                P++;
                while (1) {
                    if (P >= bufLen || X >= Width) break;
                    chars = bufChars(P);
                    Ch = chars[0];
                    if (Ch == '*') {
                        Color = EditorCommentColor;
                    
                        ::setCell(Cells[X], '*', Color);
                        X++;
                        P++;
                        if (P >= bufLen || X >= Width) break;
                        chars = bufChars(P);
                        Ch = chars[0];
                        if (Ch == '/') {
                            Color = EditorCommentColor;
                        
                            ::setCell(Cells[X], Ch, Color);
                            tokenIsComment = false;
                            Color = EditorTextColor;
                            X++;
                            P++;
                            break;
                        }   else
                        if (Ch == '\r' || Ch == '\n') {
                            while (X < Width)
                            ::setCell(Cells[X++], ' ', Color);
                            P++;
                            break;
                        }   else {
                            ::setCell(Cells[X], Ch, Color);
                            X++;
                            P++;
                            if (P >= bufLen || X >= Width) break;
                        }
                    }   else
                    if (Ch == '\r' || Ch == '\n') {
                        Color = EditorCommentColor;
        
                        while (X < Width)
                        ::setCell(Cells[X++], ' ', Color);
                        P++;
                        if (P >= bufLen || X >= Width) break;
                    }   else {
                        Color = EditorCommentColor;
                    
                        ::setCell(Cells[X], Ch, Color);
                        X++;
                        P++;
                        if (P >= bufLen || X >= Width) break;
                    }
                }
            }   else {
                Color = EditorTextColor;
        
                ::setCell(Cells[X], Ch, Color);
                X++;
                P++;
                if (P >= bufLen || X >= Width) break;
            }
        }   else
        if (Ch == '(') {
            Color = EditorTextColor;
        
            ::setCell(Cells[X], '(', Color);
            X++;
            P++;
            chars = bufChars(P);
            Ch = chars[0];
            if (P >= bufLen || X >= Width) break;
            
            // ----------------------------
            // old style pascal comment
            // ----------------------------
            if (Ch == '*') {
                tokenIsComment = true;
                Color = EditorCommentColor;

                ::setCell(Cells[X-1], '(', Color);
                ::setCell(Cells[X  ], '*', Color);
                X++;
                P++;
                while (1) {
                    if (P >= bufLen || X >= Width) break;
                    chars = bufChars(P);
                    Ch = chars[0];
                    if (Ch == '*') {
                        ::setCell(Cells[X], '*', Color);
                        X++;
                        P++;
                        if (P >= bufLen || X >= Width) break;
                        chars = bufChars(P);
                        Ch = chars[0];
                        if (Ch == ')') {
                            ::setCell(Cells[X], Ch, Color);
                            tokenIsComment = false;
                            Color = EditorTextColor;
                            X++;
                            P++;
                            break;
                        }   else
                        if (Ch == '\r' || Ch == '\n') {
                            while (X < Width)
                            ::setCell(Cells[X++], ' ', Color);
                            P++;
                            break;
                        }   else {
                            ::setCell(Cells[X], Ch, Color);
                            X++;
                            P++;
                            if (P >= bufLen || X >= Width) break;
                        }
                    }   else
                    if (Ch == '\r' || Ch == '\n') {
                        Color = EditorCommentColor;
                    
                        while (X < Width)
                        ::setCell(Cells[X++], ' ', Color);
                        P++;
                        if (P >= bufLen || X >= Width) break;
                    }   else {
                        Color = EditorCommentColor;
                    
                        ::setCell(Cells[X], Ch, Color);
                        X++;
                        P++;
                        if (P >= bufLen || X >= Width) break;
                    }
                }
            }   else {
                Color = EditorTextColor;
            
                ::setCell(Cells[X], Ch, Color);
                X++;
                P++;
                if (P >= bufLen || X >= Width) break;
            }
        }   else
        if (Ch == '*') {
            if (tokenIsComment)
            Color = EditorCommentColor; else
            Color = EditorTextColor;
        
            ::setCell(Cells[X], '*', Color);
            X++;
            P++;
            if (P >= bufLen || X >= Width) break;
            chars = bufChars(P);
            Ch = chars[0];
            
            // ----------------------------
            // dBase comment **
            // ----------------------------
            if (Ch == '*') {
                tokenIsComment = true;
                Color = EditorCommentColor;
            
                ::setCell(Cells[X-1], Ch, Color);
                if (X < Width) {
                    do  {
                        Color = EditorCommentColor;
                    
                        ::setCell(Cells[X++], Ch, Color);
                        P++;
                        chars = bufChars(P);
                        Ch = chars[0];
                        if (Ch == '\r' || Ch == '\n') {
                            while (X < Width)
                            ::setCell(Cells[X++], ' ', Color);
                            P++;
                            break;
                        }
                    }   while (X < Width);
                    ++P;
                }   else break;
            }   else
                
            // ----------------------------
            // end of c comment
            // ----------------------------
            if (Ch == '/') {
                tokenIsComment = false;
                Color = EditorCommentColor;
                
                ::setCell(Cells[X], '/', Color);
                X++;
                P++;
                if (P >= bufLen || X >= Width) break;
            }   else
                
            // ----------------------------
            // end of pascal comment
            // ----------------------------
            if (Ch == ')') {
                tokenIsComment = false;
                Color = EditorCommentColor;

                ::setCell(Cells[X], ')', Color);
                X++;
                P++;
                if (P >= bufLen || X >= Width) break;
            }   else {
                Color = EditorCommentColor;
            
                ::setCell(Cells[X], '*', Color);
                X++;
                P++;
                if (P >= bufLen || X >= Width) break;
            }
        }   else
        if (Ch == '\r' || Ch == '\n') {
            tokenIsComment = false;
            Color = EditorTextColor;
        
            while (X < Width)
            ::setCell(Cells[X++], ' ', Color);
            P++;
            break;
        }   else
        if (Ch == '\t') {
            if (tokenIsComment)
            Color = EditorCommentColor; else
            Color = EditorTextColor;
        
            if (X < Width) {
                do {
                    ::setCell(Cells[X++], ' ', Color);
                }   while (X%8 != 0 && X < Width);
                ++P;
            }   else break;
        }   else {
            if (tokenIsComment)
            Color = EditorCommentColor; else
            Color = EditorTextColor;

            if (!formatCell(Cells, (uint&) X, chars, P, Color))
            break;
        }
    }
    
    Color = EditorTextColor;

    while (X < Width)
    ::setCell(Cells[X++], ' ', Color);
}

// -----------------------------------------------------------------
// get the word under the cursor:
// -----------------------------------------------------------------
std::string TSyntaxFileEditor::getWordUnderCursor() {
    std::string word;
    
    uint wordEnd   = nextWord(curPtr);
    uint wordStart = prevWord(wordEnd);
    
    for (uint i = wordStart; i < wordEnd; ++i) {
        char c = bufChar(i);
        if (!std::isspace(c))
        word.push_back(c);
    }
    
    return word;
}
