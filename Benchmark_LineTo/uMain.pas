unit uMain;

INTERFACE

uses
  Windows, Forms, SysUtils, ExtCtrls, Controls, StdCtrls, Classes,  Graphics, Math, uBmpLine;

type
  TForm1 = class(TForm)
    imgAPI      : TImage;
    imgALGO     : TImage;
    imgScene    : TImage;
    btnAPITest  : TButton;
    btnALGOTest : TButton;
    btnRockets  : TButton;
    Timer1      : TTimer;
    procedure btnAPITestClick (Sender: TObject);
    procedure btnALGOTestClick(Sender: TObject);
    procedure btnRocketsClick (Sender: TObject);
    procedure Timer1Timer     (Sender: TObject);
    procedure FormCreate      (Sender: TObject);
    procedure FormDestroy     (Sender: TObject);
  end;

var
  Form1: TForm1;

IMPLEMENTATION
{$R *.dfm}

type
  TRocket = record
    TrajectoryArray : TBmp32Line;
    TrajectColArray : TBmp32LineCol;
    ProgressIndex   : Integer;
  end;
  TFleet  = array of TRocket;

const
  XMAX  =  400;
  XMIN  = -200;
  YMAX  =  400;
  YMIN  = -200;
  TIMES =  1000000; //Nbre d'itérations dans les boucles de traçage.
  QROCKET : TRGBQuad = (rgbBlue: 100; rgbGreen: 100; rgbRed: 100; rgbReserved: 0);
  QNOZZLE : TRGBQuad = (rgbBlue: 255; rgbGreen: 255; rgbRed: 255; rgbReserved: 0);
  QFLAME  : TRGBQuad = (rgbBlue:  70; rgbGreen: 128; rgbRed: 255; rgbReserved: 0);

var
  gInitialScene      : TBitmap; //Un Bmp de sauvegarde des couleurs d'origine du fond pour l'animation.
  gInitialSceneInfos : TBmpMemInfos;
  gMyFleet           : TFleet;
  gVirtualTarget     : TPoint = (X:0; Y:-10);//Un point cible virtuel pour l'animation.
  gFramesCount       : Integer; //Pour calcul du FPS.
  gFPStime           : Int64;  // Pour calcul du FPS.


{___________________________________________________________________________________________________
 ________ TEST DE L'API LINETO _____________________________________________________________________}


procedure TForm1.btnAPITestClick(Sender: TObject);
	var     Btn            : TButton absolute Sender;
          Start, Elapsed : Int64;
  		    i              : Integer;
	begin
  imgAPI.Canvas.FillRect(imgAPI.Canvas.ClipRect);
  imgAPI.Refresh;
  Screen.Cursor := crHourGlass;
  RandSeed      := 0;
	Start         := GetTickCount;
  for i := 1 to TIMES do begin
    imgAPI.Canvas.Pen.Color := RandomRange(0,16777215);
    Windows.LineTo(imgAPI.Canvas.Handle, RandomRange(XMIN,XMAX), RandomRange(YMIN,YMAX));
  end;
  Elapsed := GetTickCount-Start;
  if Btn.Tag>Elapsed then begin
    Btn.Tag     := Elapsed;
    Btn.Caption := Format('API Windows.LineTo' + #13#10 +'Temps mini :   %.0n ms',[Elapsed/1]);
  end;
  imgAPI.Refresh;
  Screen.Cursor := crDefault;
end;


{___________________________________________________________________________________________________
 ________ TEST DE L'ALGO LINETO ____________________________________________________________________}


procedure TForm1.btnALGOTestClick(Sender: TObject);
  var     Btn            : TButton absolute Sender;
          Infos          : TBmpMemInfos;
          Start, Elapsed : Int64;
  		    i              : Integer;
	begin
  imgALGO.Canvas.FillRect(imgALGO.Canvas.ClipRect);
  imgALGO.Refresh;
  if not BmpGetMemInfos(imgALGO.Picture.Bitmap, Infos) then Exit;
  Screen.Cursor := crHourGlass;
  RandSeed      := 0;
	Start         := GetTickCount;
  for i := 1 to TIMES do begin
    gBmpCol.Color := RandomRange(0,16777215);
    gBmpCol.A     := 111; //Une valeur quelconque pour le canal Alpha....
    if Infos.BpP=3
      then Bmp24LineTo(Infos, RandomRange(XMIN,XMAX), RandomRange(YMIN,YMAX))  //Si pf24bit.
      else Bmp32LineTo(Infos, RandomRange(XMIN,XMAX), RandomRange(YMIN,YMAX));// Si pf32bit.
  end;
  Elapsed := GetTickCount-Start;
  if Btn.Tag>Elapsed then begin
    Btn.Tag     := Elapsed;
    Btn.Caption :=  Format('Delphi Algorithm LineTo' + #13#10 +'Temps mini :   %.0n ms',[Elapsed/1]);
  end;
  imgALGO.Refresh;
  Screen.Cursor := crDefault;
end;


{___________________________________________________________________________________________________
 ________ ANIMATION ________________________________________________________________________________}


procedure DoProgress;
  var     RocketIndex : Integer;
          i, R, G, B  : Integer;
          QTrail      : TRGBQuad; //Pour calculer la couleur de la traînée.
          FirstPix    : Integer;
  begin
  RocketIndex := 0;
  repeat
    with gMyFleet[RocketIndex] do begin
      if ProgressIndex<Length(TrajectoryArray) then TrajectoryArray[ProgressIndex]^ := QROCKET;
      case ProgressIndex of
        0   :       TrajectoryArray[0]^ := QFLAME;                //Dessin de la fusée et sa flamme.
        1..3:       TrajectoryArray[ProgressIndex]^ := QROCKET;   //                 "
        4   :       TrajectoryArray[1]^ := QNOZZLE;               //                 "
        5   :       TrajectoryArray[2]^ := QNOZZLE;               //                 "
        6   :       TrajectoryArray[3]^ := QNOZZLE;               //                 "
        7   : begin TrajectoryArray[4]^ := QNOZZLE;               //                 "
                    TrajectoryArray[1]^ := QFLAME;  end;          //                 "
        8   : begin TrajectoryArray[5]^ := QNOZZLE;               //                 "
                    TrajectoryArray[2]^ := QFLAME;  end;          //                 "
        9   : begin TrajectoryArray[6]^ := QNOZZLE;               //                 "
                    TrajectoryArray[3]^ := QFLAME;  end;          //                 "
        10  : begin TrajectoryArray[7]^ := QNOZZLE;               //                 "
                    TrajectoryArray[4]^ := QFLAME;  end;          //                 "
        11  : begin TrajectoryArray[8]^ := QNOZZLE;               //                 "
                    TrajectoryArray[5]^ := QFLAME;  end;          //                 "
        12  : begin TrajectoryArray[9]^ := QNOZZLE;               //                 "
                    TrajectoryArray[6]^ := QFLAME;  end;          //                 "
      else    begin if ProgressIndex<Length(TrajectoryArray)+3    //                 "
                      then TrajectoryArray[ProgressIndex-3]^ := QNOZZLE; //          "
                    if ProgressIndex<Length(TrajectoryArray)+6           //          "
                      then TrajectoryArray[ProgressIndex-6]^ := QFLAME;  //          "
                    if ProgressIndex<Length(TrajectoryArray)+12 then begin     //Dessin de la traînée.
                      R := TrajectColArray[ProgressIndex-12].rgbGreen shl 2;  //    Couleur de fond x 4
                      G := TrajectColArray[ProgressIndex-12].rgbGreen shl 2; // ... pour effet de "traînée
                      B := TrajectColArray[ProgressIndex-12].rgbBlue  shl 2;//  ... semi-transparente".
                      if R>255 then QTrail.rgbRed      := 255 else QTrail.rgbRed   := R;//   "
                      if G>255 then QTrail.rgbGreen    := 255 else QTrail.rgbGreen := G;//   "
                      if B>255 then QTrail.rgbBlue     := 255 else QTrail.rgbBlue  := B;//   "
                                    QTrail.rgbReserved := 0;                            //   "
                      TrajectoryArray[ProgressIndex-12]^ := QTrail;                     //   "
                    end;
                    if ProgressIndex>=Length(TrajectoryArray) then begin// => Estompage de la traînée.
                      FirstPix := ProgressIndex-Length(TrajectoryArray);
                      TrajectoryArray[FirstPix]^ := TrajectColArray[FirstPix]; //Efface le dernier pixel de la traînée.
                      for i := FirstPix+1 to Length(TrajectoryArray)-1 do begin//Estompage des pixels restants.
                        R  := Round(TrajectoryArray[i]^.rgbRed  -(TrajectoryArray[i]^.rgbRed  -TrajectColArray[i].rgbRed  )*2/i);
                        G  := Round(TrajectoryArray[i]^.rgbGreen-(TrajectoryArray[i]^.rgbGreen-TrajectColArray[i].rgbGreen)*2/i);
                        B  := Round(TrajectoryArray[i]^.rgbBlue -(TrajectoryArray[i]^.rgbBlue -TrajectColArray[i].rgbBlue )*2/i);
                        if R<0 then QTrail.rgbRed   := 0 else QTrail.rgbRed   := R;
                        if G<0 then QTrail.rgbGreen := 0 else QTrail.rgbGreen := G;
                        if B<0 then QTrail.rgbBlue  := 0 else QTrail.rgbBlue  := B;
                        TrajectoryArray[i]^ := QTrail;
                      end;
                    end;
              end;
      end;
      Inc(ProgressIndex);
      if ProgressIndex = Length(TrajectoryArray) shl 1 then begin// => suppression définitive de cette roquette de la flotte.
        if RocketIndex <> Length(gMyFleet)-1 then gMyFleet[RocketIndex] := gMyFleet[Length(gMyFleet)-1];
        Dec(RocketIndex);
        SetLength(gMyFleet, Length(gMyFleet)-1);
      end;
      Inc(RocketIndex);
    end;//with
  until RocketIndex=Length(gMyFleet);
  Form1.imgScene.Refresh;
  Inc(gFramesCount);
end;


procedure TForm1.Timer1Timer(Sender: TObject);
  begin
  if Length(gMyFleet)<>0 then DoProgress;
  Application.ProcessMessages;
  Inc(gVirtualTarget.X);
  if (gVirtualTarget.X>450) then gVirtualTarget.X := -100;
  if gFramesCount>35 then begin //Calcul du FPS:
    btnRockets.Caption :=  Format('ROCKETS  LAUNCHER' + #13#10 +'( %u FPS ) ',[Round(1000/(GetTickCount-gFPStime)*gFramesCount)]);
    gFramesCount       := 0;
    gFPStime           := GetTickCount;
  end;
  Timer1.Enabled := Length(gMyFleet)<>0;
end;


procedure TForm1.btnRocketsClick(Sender: TObject);
  var     Infos       : TBmpMemInfos;
          RandomLine  : TBmp32Line;
          ColArray    : TBmp32LineCol;
          x1,y1,x2,y2 : Integer; //Coordonnées aléatoires de RandomLine
  begin
  if not BmpGetMemInfos(imgScene.Picture.Bitmap, Infos) then Exit;
  x1 := RandomRange( 12,150);  //Coordonnée X d'un pas de tir aléatoire.
  y1 := RandomRange(150,200); // Coordonnée Y d'un pas de tir aléatoire.
  x2 := gVirtualTarget.X; //gVirtualTarget simule une cible qui se déplace.
  y2 := gVirtualTarget.Y;
  BmpGetLine(Infos,RandomLine,x1,y1,x2,y2);
  SetLength(ColArray, Length(RandomLine));
  BmpGetCol(Infos, gInitialSceneInfos, RandomLine, ColArray);
  SetLength(gMyFleet, Length(gMyFleet) + 1);
  with gMyFleet[High(gMyFleet)] do begin
    TrajectoryArray := RandomLine;
    TrajectColArray := ColArray;
    ProgressIndex   := 0;
  end;//with
  gFramesCount      := 0;
  gFPStime          := GetTickCount;
  Timer1.Enabled    := true;
end;


{___________________________________________________________________________________________________
 ___________________________________________________________________________________________________}


procedure TForm1.FormCreate(Sender: TObject);
  begin
  imgAPI  .Picture.Bitmap.Width       := imgAPI.Width;
  imgAPI  .Picture.Bitmap.Height      := imgAPI.Height;
  imgAPI  .Picture.Bitmap.PixelFormat := pf32bit;
  imgALGO .Picture.Bitmap.Width       := imgALGO.Width;
  imgALGO .Picture.Bitmap.Height      := imgALGO.Height;
  imgALGO .Picture.Bitmap.PixelFormat := pf32bit;
  imgScene.Picture.Bitmap.PixelFormat := pf32bit; //pf24bit non pris en charge pour l'animation.
  gInitialScene := TBitmap.Create; //Une sauvegarde du Bmp initial afin de rétablir les couleurs de fond après dessin.
  gInitialScene.Assign(imgScene.Picture.Bitmap);
  if not BmpGetMemInfos(gInitialScene, gInitialSceneInfos) then Exit;
end;


procedure TForm1.FormDestroy(Sender: TObject);
  begin
  gInitialScene.Free;
end;


END.
