unit uBmpLine;                                                                                      {

                 Dessin de droite point par point d'après l'algo de bresenham
                   et d'après l'algo de Cohen–Sutherland pour le clipping
                     (environ 15 fois plus rapide que Windows.LineTo).

                 - Compatibilité assurée avec l'API Windows.LineTo et Canvas.LineTo.
                 - Prend en charge l'intégralité de l'étendue de Integer.
                 - Canal Alpha du pf32bit accessible en lecture/écriture.
                 - Développé sous D7 et Windows Seven.

                                      par CARIBENSILA
                                  http://www.delphifr.com/
                                        Août 2012                                                   }


INTERFACE

uses Windows, Graphics, Dialogs, Types;

type
  TColorRec = record
    case integer of
      0 : ( Color   : TColor );
      1 : ( R,G,B,A : Byte   );
  end;
  TBmpMemInfos = record
  	BpP,              //Byte per Pixel.
    BpL,              //Byte per Line.
    Scan0,            //Adresse du 1er pixel du Bmp.
    W,                //Width du Bmp.
    H     : Integer;  //Height du Bmp.
    HDC   : THandle;  //Handle du Device Context.
 	end;
  TBmp24Line    = Array of pRGBTriple;
  TBmp32Line    = Array of pRGBQuad;
  TBmp24LineCol = Array of TRGBTriple;
  TBmp32LineCol = Array of TRGBQuad;

var
  gBmpCol : TColorRec; //Couleur courante de la ligne (similaire à Pen.Color).


  
  function  BmpGetMemInfos(BMP: TBitmap; var Infos: TBmpMemInfos): Boolean;
            {Renvoie les données nécessaires au travail en mémoire.}

  procedure BmpMoveTo  (Infos: TBmpMemInfos; X,Y: Integer);
            {Similaire à Canvas.MoveTo.}

  procedure Bmp24LineTo(Infos: TBmpMemInfos; x2,y2: Integer);
  procedure Bmp32LineTo(Infos: TBmpMemInfos; x2,y2: Integer);
            {Dessine une droite de la couleur de gBmpCol de la position courante à (x2,y2).}

  procedure BmpGetLine (Infos: TBmpMemInfos; var LineArray: TBmp24Line; x1,y1,x2,y2: Integer; DrawLastPt: Boolean = true); overload;
  procedure BmpGetLine (Infos: TBmpMemInfos; var LineArray: TBmp32Line; x1,y1,x2,y2: Integer; DrawLastPt: Boolean = true); overload;
            {Renvoie un tableau de pointeurs correspondant aux pixels de la droite.}

  procedure BmpGetCol  (InfosDest, InfosSrc: TBmpMemInfos; LineArray: TBmp24Line; var ColArray: TBmp24LineCol); overload;
  procedure BmpGetCol  (InfosDest, InfosSrc: TBmpMemInfos; LineArray: TBmp32Line; var ColArray: TBmp32LineCol); overload;
            {Renvoie le tableau des couleurs des pixels de la droite passée en paramètre.}


IMPLEMENTATION



{___________________________________________________________________________________________________
 ________ ROUTINES LOCALES : _______________________________________________________________________}



function ClipLine(var x1,y1,x2,y2: Integer; BmpXmax,BmpYmax: Integer; var DrawLastPt: Boolean): Boolean;
        {Permet le clipping (fenêtrage) de la droite (fonctionne sur toute l'étendue de Integer).}
  const
          W : Integer = 1;   // => 0001
          E : Integer = 2;  //  => 0010
          S : Integer = 4; //   => 0100
          N : Integer = 8;//    => 1000.
  var
          Region1, Region2 : Integer; //Permet de déterminer une intersection de la droite avec la fenêtre par un calcul en algèbre booléenne.
          fx1,fy1,fx2,fy2  : Double;  //Coordonnées des extrémité du segment en flottants.
  begin
  Result := false;
  //CLIPPING : Algorithme de Cohen–Sutherland: http://en.wikipedia.org/wiki/Cohen%E2%80%93Sutherland_algorithm
  if y1<0 then Region1 :=  N             else if y1>BmpYmax then Region1 :=  S  else Region1 := 0;
  if x1<0 then Region1 := (Region1 or W) else if x1>BmpXmax then Region1 := (Region1 or E);
  if y2<0 then Region2 :=  N             else if y2>BmpYmax then Region2 :=  S  else Region2 := 0;
  if x2<0 then Region2 := (Region2 or W) else if x2>BmpXmax then Region2 := (Region2 or E);
  if (Region1 and Region2)<>0 then Exit; //Le segment ne coupe pas la fenêtre => on quitte.
  DrawLastPt := Region2<>0; //Afin de pouvoir dessiner le dernier point du segment (sur un côté du Rect) lorsque Pt2 se trouve à l'extérieur de Rect.
  if (Region1 or Region2)<>0 then begin //Si le segment n'est pas entièrement contenu dans la fenêtre...
    fx1 := x1;   //Les calculs d'intersections se font en flottants pour meilleure précision.
    fy1 := y1;  //                        "
    fx2 := x2; //                         "
    fy2 := y2;//                          "
    repeat
      if (Region1 or Region2)=0 then begin // Le segment est contenu dans la fenêtre => ...
        x1 := Round(fx1);                 //
        y1 := Round(fy1);                //...on retranstype les flottants temporaires en entiers...
        x2 := Round(fx2);               //
        y2 := Round(fy2);              //
        Break;                        //   ...et on sort de la boucle.
      end;
      if (Region1 and Region2)<>0 then Exit //le segment ne coupe pas la fenêtre => on quitte.
      else begin //Sinon, on calcule les coordonnées de(s) l'intersection(s) segment/bord(s) de la fenêtre.
        if Region1<>0 then begin //Au moins une extrémités est hors de la fenêtre. Si c'est le Pt1...
          if (Region1 and N)=N then begin                       //Le Pt1 est en région Nord.
              fx1:= fx1 + (fx1-fx2)*fy1/(fy2-fy1);
              fy1:= 0;  end
          else  if (Region1 and S)=S then begin              //Le Pt1 est en région Sud.
                    fx1:= fx1 + (fx2-fx1)*(BmpYmax-fy1)/(fy2-fy1);
                    fy1:= BmpYmax;  end
                else  if (Region1 and E)=E then begin    //Le Pt1 est en région Est.
                          fy1:= fy1 + (fy2-fy1)*(BmpXmax-fx1)/(fx2-fx1);
                          fx1:= BmpXmax;  end
                      else begin                    //Le Pt1 est en région Ouest.
                          fy1:= fy1 + (fy1-fy2)*fx1/(fx2-fx1);
                          fx1:= 0;        end;
          if fy1<0 then Region1 :=  N             else if fy1>BmpYmax then Region1 :=  S else Region1 := 0;
          if fx1<0 then Region1 := (Region1 or W) else if fx1>BmpXmax then Region1 := (Region1 or E);
        end
        else begin //Au moins une extrémités est hors de la fenêtre. Si c'est le Pt2...
          if (Region2 and N)= N then begin                       //Le Pt2 est en région Nord.
            fx2 := fx1 + (fx1-fx2)*fy1/(fy2-fy1);
            fy2 := 0;  end
          else  if (Region2 and S)=S then begin              //Le Pt2 est en région Sud.
                  fx2 := fx1 + (fx2-fx1)*(BmpYmax-fy1)/(fy2-fy1);
                  fy2 := BmpYmax;  end
                else  if (Region2 and E)=E then begin    //Le Pt2 est en région Est.
                        fy2 := fy1 + (fy2-fy1)*(BmpXmax-fx1)/(fx2-fx1);
                        fx2 := BmpXmax;  end
                      else  begin                    //Le Pt2 est en région Ouest.
                              fy2 := fy1 + (fy1-fy2)*fx1/(fx2-fx1);
                              fx2 := 0;  end;
          if fy2<0 then Region2 :=  N             else if fy2>BmpYmax then Region2 :=  S else Region2 := 0;
          if fx2<0 then Region2 := (Region2 or W) else if fx2>BmpXmax then Region2 := (Region2 or E);
        end;
      end;
    until false;
  end;
  Result := true;
end;



{___________________________________________________________________________________________________
 ________ ROUTINES EXPORTEES : _____________________________________________________________________}



function BmpGetMemInfos(BMP: TBitmap; var Infos: TBmpMemInfos): Boolean;
  begin
  Result := true;
  case BMP.PixelFormat of
    pf24bit :	Infos.BpP := 3;
    pf32bit :	Infos.BpP := 4;
    else begin
      ShowMessage('Format de Bitmap non supporté !'#10#10'(pf24bit ou pf32bit uniquement)');
      Result := false;
      Exit;
    end;
  end;
  Infos.W := BMP.Width;
  Infos.H := BMP.Height;
  if (Infos.W<>0) and (Infos.H<>0) and (BMP<>nil) then begin
    Infos.Scan0 := Integer(BMP.ScanLine[0]);
    Infos.BpL   := (((BMP.Width * Infos.BpP shl 3) + 31) and -31) shr 3; end
  else begin
    ShowMessage('Une ou deux dimensions du Bitmap sont nulles !');
    Result := false;
    Exit;
  end;
  if (BMP.Height>1) and (Integer(BMP.ScanLine[1])-Infos.Scan0>0) then begin
    ShowMessage('Top-Down DIB non supporté !'#10#10'(Bottom-Up DIB uniquement)');
    Result :=  false;
    Exit;
  end;
  Infos.HDC := BMP.Canvas.Handle;
end;



procedure BmpMoveTo(Infos: TBmpMemInfos; X,Y: Integer);
  begin
  MoveToEx(Infos.HDC,X,Y,nil); //MAJ du PenPos pour compatibilité avec l'API et le Canvas.LineTo.
end;



procedure Bmp24LineTo(Infos: TBmpMemInfos; x2,y2: Integer);
  var
          DrawLastPt : Boolean;   //Pour savoir si l'algo doit dessiner le dernier point du segment (=> comme LineTo).
          de,dx,dy   : Integer;   //Variation de l'erreur, variation en X, variation en Y.
          x1,y1      : Integer;   //Coordonnées du premier point du segment.
          Pt1        : TPoint;    //Coordonnées du premier point du segment.
          Col3       : TRGBTriple;//Couleur de Canvas.Pen pour pf24bit.
          pPix3      : pRGBTriple;//Pointeur de pixel pour pf24bit.
          MemLineSize: Integer;   //Largeur en bytes du Bitmap en mémoire  (peut être négatif dans l'algo pour limiter le nombre de lignes de code).
          MemPixSize : Integer;   //Largeur en bytes d'un pixel en mémoire (peut être négatif dans l'algo pour limiter le nombre de lignes de code).
          PixelNbr   : Integer;   //Index de boucle.
  begin
  MoveToEx(Infos.HDC,x2,y2,@Pt1); //MAJ du PenPos pour compatibilité avec l'API et le Canvas.LineTo.
  x1 := Pt1.X;
  y1 := Pt1.Y;
  if not ClipLine(x1,y1,x2,y2,Infos.W-1,Infos.H-1,DrawLastPt) then Exit;
  //TRACE DE SEGMENT selon Bresenham: http://fr.wikipedia.org/wiki/Algorithme_de_trac%C3%A9_de_segment_de_Bresenham
  //                                  Voir l'algo brut en Delphi après le END final.
  if x2<x1 then begin
    dx          :=  x1-x2;
    MemPixSize  := -Infos.BpP  end
  else begin
    dx          :=  x2-x1;
    MemPixSize  :=  Infos.BpP;
  end;
  if y2<y1 then begin
    dy          :=  y1-y2;
    MemLineSize := -Infos.BpL;  end
  else begin
    dy          :=  y2-y1;
    MemLineSize :=  Infos.BpL
  end;
  Col3.rgbtRed  := gBmpCol.R;
  Col3.rgbtGreen:= gBmpCol.G;
  Col3.rgbtBlue := gBmpCol.B;
  pPix3         := pRGBTriple(Infos.Scan0 - y1*Infos.BpL + x1*3);
  if dx>=dy then begin
    de := dx;
    dx := dx shl 1;
    dy := dy shl 1;
    for PixelNbr := 1 to de do begin
      pPix3^ := Col3;
      Inc(Integer(pPix3),MemPixSize);
      Dec(de,dy);
      if de<0 then begin
        Dec(Integer(pPix3),MemLineSize);
        Inc(de,dx);
      end;
    end;  end
  else begin //dx<dy
    de := dy;
    dy := dy shl 1;
    dx := dx shl 1;
    for PixelNbr := 1 to de do begin
      pPix3^ := Col3;
      Dec(Integer(pPix3),MemLineSize);
      Dec(de,dx);
      if de<0 then begin
        Inc(Integer(pPix3),MemPixSize);
        Inc(de,dy);
      end;
    end;
  end;
  if DrawLastPt then pPix3^ := Col3;
end;



procedure Bmp32LineTo(Infos: TBmpMemInfos; x2,y2: Integer);
  var
          DrawLastPt : Boolean; //Pour savoir si l'algo doit dessiner le dernier point du segment (=> comme LineTo).
          de,dx,dy   : Integer; //Variation de l'erreur, variation en X, variation en Y.
          x1,y1      : Integer; //Coordonnées du premier point du segment.
          Pt1        : TPoint;  //Coordonnées du premier point du segment.
          Col4       : TRGBQuad;//Couleur de Canvas.Pen pour pf32bit.
          pPix4      : pRGBQuad;//Pointeur de pixel pour pf32bit.
          MemLineSize: Integer; //Largeur en bytes du Bitmap en mémoire  (peut être négatif dans l'algo pour limiter le nombre de lignes de code).
          MemPixSize : Integer; //Largeur en bytes d'un pixel en mémoire (peut être négatif dans l'algo pour limiter le nombre de lignes de code).
          PixelNbr   : Integer; //Index de boucle.
  begin
  MoveToEx(Infos.HDC,x2,y2,@Pt1); //MAJ du PenPos pour compatibilité avec l'API et le Canvas.LineTo.
  x1 := Pt1.X;
  y1 := Pt1.Y;
  if not ClipLine(x1,y1,x2,y2,Infos.W-1,Infos.H-1,DrawLastPt) then Exit;
  //TRACE DE SEGMENT selon Bresenham: http://fr.wikipedia.org/wiki/Algorithme_de_trac%C3%A9_de_segment_de_Bresenham
  //                                  Voir l'algo brut après le END. final.
  if x2<x1 then begin
    dx          :=  x1-x2;
    MemPixSize  := -Infos.BpP  end
  else begin
    dx          :=  x2-x1;
    MemPixSize  :=  Infos.BpP;
  end;
  if y2<y1 then begin
    dy          :=  y1-y2;
    MemLineSize := -Infos.BpL;  end
  else begin
    dy          :=  y2-y1;
    MemLineSize :=  Infos.BpL
  end;
  with Col4 do begin
    rgbRed      := gBmpCol.R;
    rgbGreen    := gBmpCol.G;
    rgbBlue     := gBmpCol.B;
    rgbReserved := gBmpCol.A;
  end;//with
  pPix4         := pRGBQuad(Infos.Scan0 - y1*Infos.BpL + x1*4);
  if dx>=dy then begin
    de := dx;
    dx := dx shl 1;
    dy := dy shl 1;
    for PixelNbr := 1 to de do begin
      pPix4^ := Col4;
      Inc(Integer(pPix4),MemPixSize);
      Dec(de,dy);
      if de<0 then begin
        Dec(Integer(pPix4),MemLineSize);
        Inc(de,dx);
      end;
    end;  end
  else begin //dx<dy
    de := dy;
    dy := dy shl 1;
    dx := dx shl 1;
    for PixelNbr := 1 to de do begin
      pPix4^ := Col4;
      Dec(Integer(pPix4),MemLineSize);
      Dec(de,dx);
      if de<0 then begin
        Inc(Integer(pPix4),MemPixSize);
        Inc(de,dy);
      end;
    end;
  end;
  if DrawLastPt then pPix4^ := Col4;
end;



procedure BmpGetLine(Infos: TBmpMemInfos; var LineArray: TBmp24Line; x1,y1,x2,y2: Integer; DrawLastPt: Boolean = true); overload;
  var
          de,dx,dy   : Integer;
          pPix3      : pRGBTriple;
          MemLineSize: Integer;
          MemPixSize : Integer;
          PixelNbr   : Integer;
  begin
  if not ClipLine(x1,y1,x2,y2,Infos.W-1,Infos.H-1,DrawLastPt) then Exit;
  if x2<x1 then begin
    dx := x1-x2;
    MemPixSize := -Infos.BpP  end
  else begin
    dx := x2-x1;
    MemPixSize :=  Infos.BpP;
  end;
  if y2<y1 then begin
    dy := y1-y2;
    MemLineSize := -Infos.BpL;  end
  else begin
    dy := y2-y1;
    MemLineSize :=  Infos.BpL
  end;
  pPix3 := pRGBTriple(Infos.Scan0 - y1*Infos.BpL + x1*3);
  if dx>=dy then begin
    if DrawLastPt then SetLength(LineArray,dx+1) else SetLength(LineArray,dx);
    de := dx;
    dx := dx shl 1;
    dy := dy shl 1;
    for PixelNbr := 0 to de-1 do begin
      LineArray[PixelNbr] := pPix3;
      Inc(Integer(pPix3),MemPixSize);
      Dec(de,dy);
      if de<0 then begin
        Dec(Integer(pPix3),MemLineSize);
        Inc(de,dx);
      end;
    end;  end
  else begin //dx<dy
    if DrawLastPt then SetLength(LineArray,dy+1) else SetLength(LineArray,dy);
    de := dy;
    dy := dy shl 1;
    dx := dx shl 1;
    for PixelNbr := 0 to de-1 do begin
      LineArray[PixelNbr] := pPix3;
      Dec(Integer(pPix3),MemLineSize);
      Dec(de,dx);
      if de<0 then begin
        Inc(Integer(pPix3),MemPixSize);
        Inc(de,dy);
      end;
    end;
  end;
  if DrawLastPt then LineArray[High(LineArray)] := pPix3;
end;



procedure BmpGetLine(Infos: TBmpMemInfos; var LineArray: TBmp32Line; x1,y1,x2,y2: Integer; DrawLastPt: Boolean = true); overload;
  var
          de,dx,dy   : Integer;
          pPix4      : pRGBQuad;
          MemLineSize: Integer;
          MemPixSize : Integer;
          PixelNbr   : Integer;
  begin
  if not ClipLine(x1,y1,x2,y2,Infos.W-1,Infos.H-1,DrawLastPt) then Exit;
  if x2<x1 then begin
    dx := x1-x2;
    MemPixSize := -Infos.BpP  end
  else begin
    dx := x2-x1;
    MemPixSize :=  Infos.BpP;
  end;
  if y2<y1 then begin
    dy := y1-y2;
    MemLineSize := -Infos.BpL;  end
  else begin
    dy := y2-y1;
    MemLineSize :=  Infos.BpL
  end;
  pPix4 := pRGBQuad(Infos.Scan0 - y1*Infos.BpL + x1*4);
  if dx>=dy then begin
    if DrawLastPt then SetLength(LineArray,dx+1) else SetLength(LineArray,dx);
    de := dx;
    dx := dx shl 1;
    dy := dy shl 1;
    for PixelNbr := 0 to de-1 do begin
      LineArray[PixelNbr] := pPix4;
      Inc(Integer(pPix4),MemPixSize);
      Dec(de,dy);
      if de<0 then begin
        Dec(Integer(pPix4),MemLineSize);
        Inc(de,dx);
      end;
    end;  end
  else begin //dx<dy
    if DrawLastPt then SetLength(LineArray,dy+1) else SetLength(LineArray,dy);
    de := dy;
    dy := dy shl 1;
    dx := dx shl 1;
    for PixelNbr := 0 to de-1 do begin
      LineArray[PixelNbr] := pPix4;
      Dec(Integer(pPix4),MemLineSize);
      Dec(de,dx);
      if de<0 then begin
        Inc(Integer(pPix4),MemPixSize);
        Inc(de,dy);
      end;
    end;
  end;
  if DrawLastPt then LineArray[High(LineArray)] := pPix4;
end;



procedure BmpGetCol (InfosDest,InfosSrc: TBmpMemInfos; LineArray: TBmp24Line; var ColArray: TBmp24LineCol); overload;
  var
          i, Shift : Integer;
  begin
  Shift := InfosSrc.Scan0 - InfosDest.Scan0;
  SetLength(ColArray, Length(LineArray));
  for i := 0 to High(ColArray) do ColArray[i] := pRGBTriple(Integer(LineArray[i]) + Shift)^;
end;



procedure BmpGetCol(InfosDest,InfosSrc: TBmpMemInfos; LineArray: TBmp32Line; var ColArray: TBmp32LineCol); overload;
  var
          i, Shift : Integer;
  begin
  Shift := InfosSrc.Scan0 - InfosDest.Scan0;
  SetLength(ColArray, Length(LineArray));
  for i := 0 to High(ColArray) do ColArray[i] := pRGBQuad(Integer(LineArray[i]) + Shift)^;
end;


END.////////////////////////////////////////////////////////////////////////////////////////////////



Algo de Bresenham brut en Delphi (pour pf32bit) :

procedure Bmp32BresenhamLineTo(var BmpInfo: TMemBmpInfos; x2,y2: Integer);
  const
          W : Integer = 1;   // => 0001
          E : Integer = 2;  //  => 0010
          S : Integer = 4; //   => 0100
          N : Integer = 8;//    => 1000.
  var
          Region1, Region2  : Integer;
          BmpXmax, BmpYmax  : Integer;
          fx1,fy1,fx2,fy2   : Double;
          DrawLastPoint     : Boolean;
          de,dx,dy          : Integer;
          x1,y1             : Integer;
          Col               : TRGBQuad;
          pPix              : pRGBQuad;
          MemLineSize       : Integer;
          MemPixSize        : Integer;
          i                 : Integer;
  begin
              { Algorithme de clipping (fenêtrage) de Cohen–Sutherland. VOIR :
                http://en.wikipedia.org/wiki/Cohen%E2%80%93Sutherland_algorithm }
  with BmpInfo do begin
    MoveToEx(HDC,x2,y2,@Pt1);
    x1 := Pt1.X;
    y1 := Pt1.Y;
    BmpXmax := W-1;
    BmpYmax := H-1;
  end;
  if y1<0 then Region1 :=  N             else if y1>BmpYmax then Region1 :=  S  else Region1 := 0;
  if x1<0 then Region1 := (Region1 or W) else if x1>BmpXmax then Region1 := (Region1 or E);
  if y2<0 then Region2 :=  N             else if y2>BmpYmax then Region2 :=  S  else Region2 := 0;
  if x2<0 then Region2 := (Region2 or W) else if x2>BmpXmax then Region2 := (Region2 or E);
  if (Region1 and Region2)<>0 then Exit; //le segment ne coupe pas la fenêtre => on quitte.
  DrawLastPoint := Region2<>0;//Afin de pouvoir dessiner le dernier point du segment (sur un côté du Rect) lorsque Pt2 se trouve à l'extérieur de Rect.
  if (Region1 or Region2)<>0 then begin //Si le segment n'est pas entièrement contenu dans la fenêtre...
    fx1 := x1;   //Les calculs d'intersections se font en flottants pour meilleure précision.
    fy1 := y1;  //                        "
    fx2 := x2; //                         "
    fy2 := y2;//                          "
    repeat
      if (Region1 or Region2)=0 then begin // Le segment est contenu dans la fenêtre => ...
        x1 := Round(fx1);                 //
        y1 := Round(fy1);                //...on retranstype les flottants temporaires en entiers...
        x2 := Round(fx2);               // ...pour dessiner les pixels du segment...
        y2 := Round(fy2);              //
        Break;                        //   ...et on sort de la boucle.
      end;
      if (Region1 and Region2)<>0 then Exit //le segment ne coupe pas la fenêtre => on quitte.
      else begin //Sinon, on calcule les coordonnées de(s) l'intersection(s) segment/bord(s) de la fenêtre.
        if Region1<>0 then begin //Au moins une extrémités est hors de la fenêtre. Si c'est le Pt1...
          if (Region1 and N)=N then begin                       //Le Pt1 est en région Nord.
              fx1:= fx1 + (fx1-fx2)*fy1/(fy2-fy1);
              fy1:= 0;  end
          else  if (Region1 and S)=S then begin              //Le Pt1 est en région Sud.
                    fx1:= fx1 + (fx2-fx1)*(BmpYmax-fy1)/(fy2-fy1);
                    fy1:= BmpYmax;  end
                else  if (Region1 and E)=E then begin    //Le Pt1 est en région Est.
                          fy1:= fy1 + (fy2-fy1)*(BmpXmax-fx1)/(fx2-fx1);
                          fx1:= BmpXmax;  end
                      else begin                    //Le Pt1 est en région Ouest.
                          fy1:= fy1 + (fy1-fy2)*fx1/(fx2-fx1);
                          fx1:= 0;        end;
          if fy1<0 then Region1 :=  N             else if fy1>BmpYmax then Region1 :=  S  else Region1 := 0;
          if fx1<0 then Region1 := (Region1 or W) else if fx1>BmpXmax then Region1 := (Region1 or E);
        end
        else begin //Au moins une extrémités est hors de la fenêtre. Si c'est le Pt2...
          if (Region2 and N)= N then begin                       //Le Pt2 est en région Nord.
            fx2 := fx1 + (fx1-fx2)*fy1/(fy2-fy1);
            fy2 := 0;  end
          else  if (Region2 and S)=S then begin              //Le Pt2 est en région Sud.
                  fx2 := fx1 + (fx2-fx1)*(BmpYmax-fy1)/(fy2-fy1);
                  fy2 := BmpYmax;  end
                else  if (Region2 and E)=E then begin    //Le Pt2 est en région Est.
                        fy2 := fy1 + (fy2-fy1)*(BmpXmax-fx1)/(fx2-fx1);
                        fx2 := BmpXmax;  end
                      else  begin                    //Le Pt2 est en région Ouest.
                              fy2 := fy1 + (fy1-fy2)*fx1/(fx2-fx1);
                              fx2 := 0;  end;
          if fy2<0 then Region2 :=  N             else if fy2>BmpYmax then Region2 :=  S  else Region2 := 0;
          if fx2<0 then Region2 := (Region2 or W) else if fx2>BmpXmax then Region2 := (Region2 or E);
        end;
      end;
    until false;
  end;
  {               Algorithme de tracé de segment de Bresenham. VOIR :
         http://fr.wikipedia.org/wiki/Algorithme_de_trac%C3%A9_de_segment_de_Bresenham
  NB1: Comme Canvas.LineTo, cet algo ne dessine pas le dernier pixel du segment.
  NB2: Le cas dx=dy=0 n'est pas traité dans cet algo (point unique).                                }
  Col.rgbRed      := gBmpCol.R;
  Col.rgbGreen    := gBmpCol.G;
  Col.rgbBlue     := gBmpCol.B;
  Col.rgbReserved := gBmpCol.A;
  dx   := x2-x1;
  dy   := y2-y1;
  pPix := pRGBQuad(BmpInfo.Scan0 - y1*BmpInfo.BpL + x1*4);
  MemLineSize := BmpInfo.BpL;
  MemPixSize :=  BmpInfo.BpP;
  { On traite en priorité le dessin de verticale ou d'horizontale (statistiquement plus courant). }

  if dy=0 then begin                 //Ligne strictement horizontale...
    if dx<0 then begin
      for x1 := x1 downto x2+1 do begin // ...dessinée de droite à gauche.
        pPix^ := Col;
        Dec(pPix);
      end; end
    else if dx>0 then begin
      for x1 := x1 to x2-1 do begin
        pPix^ := Col;   //        ...dessinée de gauche à droite.
        Inc(pPix);
      end;
    end;
    if DrawLastPoint then pPix^ := Col;
    Exit;
  end;

  if dx=0 then begin                 //Ligne strictement verticale...
    if dy<0 then begin              // ...dessinée de bas en haut.
      for y1 := y1 downto y2+1 do begin
        pPix^ := Col;
        Inc(Integer(pPix), MemLineSize);
      end; end
    else begin             // dy>0 => ...dessinée de haut en bas.
      for y1 := y1 to y2-1 do begin
        pPix^ := Col;
        Dec(Integer(pPix), MemLineSize);
      end;
    end;
    if DrawLastPoint then pPix^ := Col;
    Exit;
  end;

  // Reste à traiter le dessin de ligne oblique:
  if dx<0 then begin
    if dy>0 then begin
      if dx+dy<=0 then begin
        de := dx;
        dx := dx  shl 1;
        dy := dy shl 1;
        for i := 1 to -de do begin
          pPix^ := Col;
          Dec(Integer(pPix), MemPixSize);
          Inc(de,dy);
          if de >= 0 then begin
            Dec(Integer(pPix), MemLineSize);
            Inc(de,dx);
          end;
        end;  end
      else begin
        de := dy;
        dy := de  shl 1;
        dx := dx shl 1;
        for i := 1 to de do begin
          pPix^ := Col;
          Dec(Integer(pPix), MemLineSize);
          Inc(de,dx);
          if de <= 0 then begin
            Dec(Integer(pPix), MemPixSize);
            Inc(de,dy);
          end;
        end;
      end;  end
    else begin
      if dx <= dy then begin
        de  := dx;
        dx := de  shl 1;
        dy := dy shl 1;
        for i := 1 to -de do begin
          pPix^ := Col;
          Dec(Integer(pPix), MemPixSize);
          Dec(de,dy);
          if de >= 0 then begin
            Inc(Integer(pPix), MemLineSize);
            Inc(de,dx);
          end;
        end;  end
      else begin
        de  := dy;
        dy := de shl 1;
        dx := dx shl 1;
        for i := 1 to -de do begin
          pPix^ := Col;
          Inc(Integer(pPix), MemLineSize);
          Dec(de,dx);
          if de >= 0 then begin
            Dec(Integer(pPix), MemPixSize);
            Inc(de,dy);
          end;
        end;
      end;
    end;  end
  else begin //dx>0
    if dy>0 then begin
      if dx>=dy then begin
        de:= dx;
        dx:= de  shl 1;
        dy:= dy shl 1;
        for i := 1 to de do begin
          pPix^ := Col;
          Inc(Integer(pPix), MemPixSize);
          Dec(de,dy);
          if de<0 then begin
            Dec(Integer(pPix), MemLineSize);
            Inc(de,dx);
          end;
        end;  end
      else begin
        de  := dy;
        dy := de  shl 1;
        dx := dx shl 1;
        for i := 1 to de do begin
          pPix^ := Col;
          Dec(Integer(pPix), MemLineSize);
          Dec(de,dx);
          if de < 0 then begin
            Inc(Integer(pPix), MemPixSize);
            Inc(de,dy)
          end;
        end;
      end;  end
    else begin
      if dx+dy >= 0 then begin
        de  := dx;
        dx := de  shl 1;
        dy := dy shl 1;
        for i := 1 to de do begin
          pPix^ := Col;
          Inc(Integer(pPix), MemPixSize);
          Inc(de,dy);
          if de < 0 then begin
            Inc(Integer(pPix), MemLineSize);
            Inc(de,dx);
          end;
        end;  end
      else begin
        de  := dy;
        dy := de  shl 1;
        dx := dx shl 1;
        for i := 1 to -de do begin
          pPix^ := Col;
          Inc(Integer(pPix), MemLineSize);
          Inc(de,dx);
          if de > 0 then begin
            Inc(Integer(pPix), MemPixSize);
            Inc(de,dy);
          end;
        end;
      end;
    end;
  end;
  if DrawLastPoint then pPix^ := Col;
end;

