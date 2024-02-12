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
#if 0
    int flag = 0;
    int  pos = 0;

    TStringView chars;
    static int  xpos = 0;
    static int  ypos = 1;
    
    static uint P = 0;
    char   Ch;

    if (event.what == evKeyDown)
    {
        while (1) {
            if (P >= bufLen) break;
            chars  = bufChars(P);
            Ch     = chars[0];
            xpos   = xpos + 1;
            if (EOL(Ch)) {
                shadowData[ypos] = xpos;
                ypos++;
                P += 2;
                xpos = 0;
            }
            P++;
        }
        
        xpos = cursor.x;
        ypos = cursor.y;
        
        if (event.keyDown.keyCode == kbLeft)
        {
            if ((xpos-1) < 0) {
                xpos = 0;
                if ((ypos-1) < 0) {
                    ypos = 0;
                    xpos = shadowData[ypos];
                    setCursor(xpos, ypos);
                    return;
                }   else {
                    ypos = ypos - 1;
                    xpos = shadowData[ypos];
                    setCursor(xpos, ypos);
                    return;
                }
            }   else {
                xpos  = xpos - 1;
                chars = bufChars(xpos);
                Ch    = chars[0];
                
                if (EOL(Ch)) {
                    xpos = shadowData[ypos];
                    xpos = xpos + 2;
                    ypos = ypos - 1;
                    if (ypos < 0) {
                        ypos = 0;
                    }
                }
                setCursor(xpos, ypos);
                writeChar(xpos, ypos, Ch, 0x0f, 1);
                return;
            }
/*
            if ((event.keyDown.controlKeyState == 0x310)
            ||  (event.keyDown.controlKeyState == 0x330)
            ||  (event.keyDown.controlKeyState == 0x390)
            ||  (event.keyDown.controlKeyState == 0x110)
            ||  (event.keyDown.controlKeyState == 0x130)
            ||  (event.keyDown.controlKeyState == 0x190)) {
                clearEvent(event);
                
                selecting = true;
                selected  = true;

                if ((--cursor.x < 1) && (--cursor.y < 1)) {
                    cursor.x = 1;
                    cursor.y = 1;
                    setCursor(cursor.x, cursor.y);
                    return;
                }
                
                Ch = bufChar(pos);
                
                if (Ch == '\n' || Ch == '\r') {
                    Ch  = bufChar(pos);
                    setCursor( cursor.x, cursor.y - 1);
                    writeChar( cursor.x, cursor.y, Ch, 0x0f, 1);
                    return;
                }
                
                selStart  = cursor.x - 1;
                selEnd    = cursor.x    ;
                
                //TColorAttr Color = { 0xffff00, 0x008000 };
                uchar Color = 0x0f;
                writeChar(cursor.x-1, cursor.y, Ch, 0x0f, 1);
                
                setCursor(cursor.x-1, cursor.y);
                return;
            }
*/
        }   else
        if (event.keyDown.keyCode == kbRight)
        {
            xpos  = xpos + 1;
            chars = bufChars(xpos);
            Ch    = chars[0];
            
            if (EOL(Ch)) {
                ypos = ypos + 1;
                xpos = 0;
            }
            
            setCursor(xpos, ypos);
            
            /*
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
                writeChar(cursor.x, cursor.y, Ch, 1, 1);
                
                setCursor(cursor.x + 1, cursor.y);
                return;
            }
*/
        }   else
    }
#endif

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
    int L = 0;

    Color = EditorTextColor;
    token = "";
    
    // ---------------------------------------
    // set new size of shadowCopy - TColorAttr
    // ---------------------------------------
    shadowCopy.clear();
    
    while (1) {
        if (P >= bufLen || X >= Width) break;
        tokenIsComment = false;
        chars = bufChars(P);
        
        Color = EditorTextColor;
        shadowCopy.push_back(Color);
        Ch = chars[0];
        
        // ----------------------------
        // parse white space's ...
        // ----------------------------
        if (Ch == ' ') {
            while (X < Width) {
                Color = EditorTextColor;
                shadowCopy.push_back(Color);
                
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
            shadowCopy.push_back(Color);

            ::setCell(Cells[X++], Ch, Color);
            L++;
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
                    shadowCopy.push_back(Color);
                    
                    ::setCell(Cells[X++], Ch, Color);
                    L++;
                    
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
                    shadowCopy.push_back(Color);

                    if (X >= Width) break;
                    ::setCell(Cells[X++], c, Color);
                    L++;
                }
            }   else {
                for (char &c: token) {
                    if (X >= Width) break;
                    Color = EditorTextColor;
                    shadowCopy.push_back(Color);
                    
                    ::setCell(Cells[X++], c, Color);
                    L++;
                }
            }
            token = "";
        }
        
        // ----------------------------
        // parse comment's ...
        // ----------------------------
        if (Ch == '&') {
            Color = EditorTextColor;
            shadowCopy.push_back(Color);

            ::setCell(Cells[X], '&', Color);
            X++;
            P++;
            L++;
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
                        shadowCopy.push_back(Color);
                        ::setCell(Cells[X++], Ch, Color);
                        L++;
                        P++;
                        chars = bufChars(P);
                        Ch = chars[0];
                        if (Ch == '\r' || Ch == '\n') {
                            while (X < Width) {
                                shadowCopy.push_back(Color);
                                ::setCell(Cells[X++], ' ', Color);
                            }
                            shadowData[cursor.y] = L;
                            P++;
                            L = 1;
                            break;
                        }
                    }   while (X < Width);
                    ++P;
                }   else break;
            }   else
            if (Ch == '\r' || Ch == '\n') {
                Color = EditorCommentColor;
            
                while (X < Width) {
                    shadowCopy.push_back(Color);
                    ::setCell(Cells[X++], ' ', Color);
                    L++;
                }
                P++;
                break;
            }   else {
                Color = EditorTextColor;
                shadowCopy.push_back(Color);

                ::setCell(Cells[X], Ch, Color);
                X++;
                P++;
                L++;
                if (P >= bufLen || X >= Width) break;
            }
        }   else
        if (Ch == '/') {
            Color = EditorTextColor;
            shadowCopy.push_back(Color);
        
            ::setCell(Cells[X], '/', Color);
            X++;
            P++;
            L++;
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
                        shadowCopy.push_back(Color);
                        ::setCell(Cells[X++], Ch, Color);
                        L++;
                        P++;
                        chars = bufChars(P);
                        Ch = chars[0];
                        if (Ch == '\r' || Ch == '\n') {
                            while (X < Width) {
                                shadowCopy.push_back(Color);
                                ::setCell(Cells[X++], ' ', Color);
                            }
                            shadowData[cursor.y] = L;
                            L = 1;
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
                shadowCopy.push_back(Color);

                ::setCell(Cells[X-1], '/', Color);
                ::setCell(Cells[X  ], '*', Color);
                L++;
                X++;
                P++;
                while (1) {
                    if (P >= bufLen || X >= Width) break;
                    chars = bufChars(P);
                    Ch = chars[0];
                    if (Ch == '*') {
                        Color = EditorCommentColor;
                        shadowCopy.push_back(Color);
                    
                        ::setCell(Cells[X], '*', Color);
                        L++;
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
                            L++;
                            X++;
                            P++;
                            break;
                        }   else
                        if (Ch == '\r' || Ch == '\n') {
                            while (X < Width) {
                                ::setCell(Cells[X++], ' ', Color);
                            }
                            shadowData[cursor.y] = L;
                            L = 1;
                            P++;
                            break;
                        }   else {
                            ::setCell(Cells[X], Ch, Color);
                            L++;
                            X++;
                            P++;
                            if (P >= bufLen || X >= Width) break;
                        }
                    }   else
                    if (Ch == '\r' || Ch == '\n') {
                        Color = EditorCommentColor;
                        shadowCopy.push_back(Color);
        
                        while (X < Width) {
                            ::setCell(Cells[X++], ' ', Color);
                            L++;
                        }
                        shadowData[cursor.y] = L;
                        L = 1;
                        P++;
                        if (P >= bufLen || X >= Width) break;
                    }   else {
                        Color = EditorCommentColor;
                        shadowCopy.push_back(Color);
                    
                        ::setCell(Cells[X], Ch, Color);
                        L++;
                        X++;
                        P++;
                        if (P >= bufLen || X >= Width) break;
                    }
                }
            }   else {
                Color = EditorTextColor;
                shadowCopy.push_back(Color);
        
                ::setCell(Cells[X], Ch, Color);
                L++;
                X++;
                P++;
                if (P >= bufLen || X >= Width) break;
            }
        }   else
        if (Ch == '(') {
            Color = EditorTextColor;
            shadowCopy.push_back(Color);
        
            ::setCell(Cells[X], '(', Color);
            L++;
            X++;
            P++;
            chars = bufChars(P);
            Ch    = chars[0];
            if (P >= bufLen || X >= Width) break;
            
            // ----------------------------
            // old style pascal comment
            // ----------------------------
            if (Ch == '*') {
                tokenIsComment = true;
                Color = EditorCommentColor;
                shadowCopy.push_back(Color);

                ::setCell(Cells[X-1], '(', Color);
                ::setCell(Cells[X  ], '*', Color);
                L++;
                X++;
                P++;
                while (1) {
                    if (P >= bufLen || X >= Width) break;
                    chars = bufChars(P);
                    Ch = chars[0];
                    if (Ch == '*') {
                        ::setCell(Cells[X], '*', Color);
                        L++;
                        X++;
                        P++;
                        if (P >= bufLen || X >= Width) break;
                        chars = bufChars(P);
                        Ch = chars[0];
                        if (Ch == ')') {
                            ::setCell(Cells[X], Ch, Color);
                            tokenIsComment = false;
                            Color = EditorTextColor;
                            shadowCopy.push_back(Color);
                            L++;
                            X++;
                            P++;
                            break;
                        }   else
                        if (Ch == '\r' || Ch == '\n') {
                            while (X < Width) {
                                ::setCell(Cells[X++], ' ', Color);
                            }
                            shadowData[cursor.y] = L;
                            L = 1;
                            P++;
                            break;
                        }   else {
                            ::setCell(Cells[X], Ch, Color);
                            L++;
                            X++;
                            P++;
                            if (P >= bufLen || X >= Width) break;
                        }
                    }   else
                    if (Ch == '\r' || Ch == '\n') {
                        Color = EditorCommentColor;
                        shadowCopy.push_back(Color);
                    
                        while (X < Width) {
                            ::setCell(Cells[X++], ' ', Color);
                        }
                        shadowData[cursor.y] = L;
                        L = 1;
                        P++;
                        if (P >= bufLen || X >= Width) break;
                    }   else {
                        Color = EditorCommentColor;
                        shadowCopy.push_back(Color);
                    
                        ::setCell(Cells[X], Ch, Color);
                        L++;
                        X++;
                        P++;
                        if (P >= bufLen || X >= Width) break;
                    }
                }
            }   else {
                Color = EditorTextColor;
                shadowCopy.push_back(Color);
            
                ::setCell(Cells[X], Ch, Color);
                L++;
                X++;
                P++;
                if (P >= bufLen || X >= Width) break;
            }
        }   else
        if (Ch == '*') {
            if (tokenIsComment)
            Color = EditorCommentColor; else
            Color = EditorTextColor;
        
            shadowCopy.push_back(Color);

            ::setCell(Cells[X], '*', Color);
            L++;
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
                shadowCopy.push_back(Color);
            
                ::setCell(Cells[X-1], Ch, Color);
                if (X < Width) {
                    do  {
                        Color = EditorCommentColor;
                        shadowCopy.push_back(Color);
                    
                        ::setCell(Cells[X++], Ch, Color);
                        L++;
                        P++;
                        chars = bufChars(P);
                        Ch = chars[0];
                        if (Ch == '\r' || Ch == '\n') {
                            while (X < Width) {
                                shadowCopy.push_back(Color);
                                ::setCell(Cells[X++], ' ', Color);
                            }
                            shadowData[cursor.y] = L;
                            L = 1;
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
                shadowCopy.push_back(Color);
                
                ::setCell(Cells[X], '/', Color);
                L++;
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
                shadowCopy.push_back(Color);

                ::setCell(Cells[X], ')', Color);
                L++;
                X++;
                P++;
                if (P >= bufLen || X >= Width) break;
            }   else {
                Color = EditorCommentColor;
                shadowCopy.push_back(Color);
            
                ::setCell(Cells[X], '*', Color);
                L++;
                X++;
                P++;
                if (P >= bufLen || X >= Width) break;
            }
        }   else
        if (Ch == '\r' || Ch == '\n') {
            tokenIsComment = false;
            Color = EditorTextColor;
            shadowCopy.push_back(Color);
        
            while (X < Width) {
                ::setCell(Cells[X++], ' ', Color);
            }
            shadowData[cursor.y] = L;
            L = 1;
            P++;
            break;
        }   else
        if (Ch == '\t') {
            if (tokenIsComment)
            Color = EditorCommentColor; else
            Color = EditorTextColor;

            shadowCopy.push_back(Color);

            if (X < Width) {
                do {
                    ::setCell(Cells[X++], ' ', Color);
                    L++;
                }   while (X%8 != 0 && X < Width);
                ++P;
            }   else break;
        }   else {
            if (tokenIsComment)
            Color = EditorCommentColor; else
            Color = EditorTextColor;

            shadowCopy.push_back(Color);

            if (!formatCell(Cells, (uint&) X, chars, P, Color))
            break;
        }
    }
    
    Color = EditorTextColor;

    while (X < Width) {
        shadowCopy.push_back(Color);
        ::setCell(Cells[X++], ' ', Color);
    }
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

#if 0
TColorAttr
TSyntaxFileEditor::mapColor(uchar index) noexcept {
    switch (index) {
        case 1: return {0xffff00, 0x008000};
        default: return errorAttr;
    }
}
#endif
