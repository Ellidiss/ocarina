------------------------------------------------------------------------------
--                                                                          --
--                           OCARINA COMPONENTS                             --
--                                                                          --
--                        O C A R I N A . U T I L S                         --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                   Copyright (C) 2013-2014 ESA & ISAE.                    --
--                                                                          --
-- Ocarina  is free software;  you  can  redistribute  it and/or  modify    --
-- it under terms of the GNU General Public License as published by the     --
-- Free Software Foundation; either version 2, or (at your option) any      --
-- later version. Ocarina is distributed  in  the  hope  that it will be    --
-- useful, but WITHOUT ANY WARRANTY;  without even the implied warranty of  --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General --
-- Public License for more details. You should have received  a copy of the --
-- GNU General Public License distributed with Ocarina; see file COPYING.   --
-- If not, write to the Free Software Foundation, 51 Franklin Street, Fifth --
-- Floor, Boston, MA 02111-1301, USA.                                       --
--                                                                          --
-- As a special exception,  if other files  instantiate  generics from this --
-- unit, or you link  this unit with other files  to produce an executable, --
-- this  unit  does not  by itself cause  the resulting  executable to be   --
-- covered  by the  GNU  General  Public  License. This exception does not  --
-- however invalidate  any other reasons why the executable file might be   --
-- covered by the GNU Public License.                                       --
--                                                                          --
--                 Ocarina is maintained by the TASTE project               --
--                      (taste-users@lists.tuxfamily.org)                   --
--                                                                          --
------------------------------------------------------------------------------

with Ada.Command_Line;           use Ada.Command_Line;
with GNAT.Directory_Operations;  use GNAT.Directory_Operations;
with GNAT.OS_Lib;                use GNAT.OS_Lib;

with Errors;                     use Errors;
with Locations;                  use Locations;
with Ocarina.Namet;                      use Ocarina.Namet;
with Ocarina.Output;                     use Ocarina.Output;
with Ocarina.Types;                      use Ocarina.Types;
with Utils;                      use Utils;

with Ocarina.Analyzer;           use Ocarina.Analyzer;
with Ocarina.Backends;           use Ocarina.Backends;
with Ocarina.Configuration;      use Ocarina.Configuration;
with Ocarina.FE_AADL;            use Ocarina.FE_AADL;
with Ocarina.FE_AADL.Parser;
with Ocarina.FE_REAL;            use Ocarina.FE_REAL;
with Ocarina.Instances;          use Ocarina.Instances;
with Ocarina.Parser;             use Ocarina.Parser;
with Ocarina.Options;            use Ocarina.Options;
with Ocarina.Files;              use Ocarina.Files;

package body Ocarina.Utils is

   AADL_Root             : Node_Id := No_Node;
   File_Name             : Name_Id := No_Name;
   Buffer                : Location;
   Language              : Name_Id := No_Name;

   -----------
   -- Reset --
   -----------

   procedure Reset is
   begin
      --  Reset Ocarina

      Ocarina.Configuration.Reset_Modules;
      Ocarina.Reset;

      --  Initialize Ocarina

      Ocarina.AADL_Version := Get_Default_AADL_Version;
      AADL_Version         := Ocarina.AADL_V2;
      Ocarina.Initialize;
      Ocarina.Configuration.Init_Modules;

      --  Reset library

      AADL_Root := No_Node;
      File_Name := No_Name;
      Language := No_Name;
   end Reset;

   -------------
   -- Version --
   -------------

   procedure Version is
   begin
      Write_Line
        ("Ocarina " & Ocarina_Version
           & " (" & Ocarina_SVN_Revision & ")");

      if Ocarina_Last_Configure_Date /= "" then
         Write_Line ("Build date: " & Ocarina_Last_Configure_Date);
      end if;

      Write_Line
        ("Copyright (c) 2003-2009 Telecom ParisTech, 2010-"
           & Ocarina_Last_Configure_Year & " ESA & ISAE");
   end Version;

   ------------------
   -- Print_Status --
   ------------------

   procedure Print_Status is
   begin
      Write_Line ("AADL version: " & Ocarina.AADL_Version'Img);
      Write_Line ("Library Path: "
                    & Get_Name_String (Default_Library_Path));
      Write_Line ("Load predefined property sets: "
                    & Ocarina.FE_AADL.Parser.Add_Pre_Prop_Sets'Img);
   end Print_Status;

   -----------
   -- Usage --
   -----------

   procedure Usage is
      Exec_Suffix : String_Access := Get_Executable_Suffix;
   begin
      Set_Standard_Error;
      Write_Line ("Usage: ");
      Write_Line ("      "
                    & Base_Name (Command_Name, Exec_Suffix.all)
                    & " [options] files");
      Write_Line ("      OR");
      Write_Line ("      "
                    & Base_Name (Command_Name, Exec_Suffix.all)
                    & " -help");
      Write_Line ("  files are a non null sequence of AADL files");

      Write_Eol;
      Write_Line ("  General purpose options:");
      Write_Line ("   -V  Output Ocarina version, then exit");
      Write_Line ("   -s  Output Ocarina search directory, then exit");

      Write_Eol;
      Write_Line ("  Scenario file options:");
      Write_Line ("   -b  Generate and build code from the AADL model");
      Write_Line ("   -z  Clean code generated from the AADL model");
      Write_Line ("   -ec Execute the generated application code and");
      Write_Line ("       retrieve coverage information");
      Write_Line ("   -er Execute the generated application code and");
      Write_Line ("       verify that there is no regression");
      Write_Line ("   -p  Only parse and instantiate the application model");
      Write_Line ("   -c  Only perform schedulability analysis");

      Write_Eol;
      Write_Line ("  Advanced user options:");
      Write_Line ("   -d  Debug mode for developpers");
      Write_Line ("   -q  Quiet mode (default)");
      Write_Line ("   -t  [script] Run Ocarina in terminal interactive mode.");
      Write_Line ("       If a script is given, interpret it then exit.");
      Write_Line ("   -v  Verbose mode for users");
      Write_Line ("   -x  Parse AADL file as an AADL scenario file");

      Ocarina.FE_AADL.Usage;
      Ocarina.FE_REAL.Usage;
      Ocarina.Backends.Usage;

      Write_Line ("   -disable-annexes={annexes}"
                    & "  Desactive one or all annexes");
      Write_Line ("       Annexes :");
      Write_Line ("        all");
      Write_Line ("        behavior");
      Write_Line ("        real");
      Write_Eol;

      Free (Exec_Suffix);
   end Usage;

   --------------------
   -- Load_AADL_File --
   --------------------

   procedure Load_AADL_File (Filename : String) is
   begin
      Language := Get_String_Name ("aadl");
      Set_Str_To_Name_Buffer (Filename);

      File_Name := Search_File (Name_Find);
      if File_Name = No_Name then
         Write_Line ("Cannot find file " & Filename);
         return;
      end if;

      Buffer := Load_File (File_Name);
      if File_Name = No_Name then
         Write_Line ("Cannot read file " & Filename);
         return;
      end if;

      AADL_Root := Parse (Language, AADL_Root, Buffer);
      Exit_On_Error
        (No (AADL_Root),
         "Cannot parse AADL specifications");
      Write_Line
        ("File " & Filename
           & " loaded and parsed sucessfully");
   end Load_AADL_File;

   -------------
   -- Analyze --
   -------------

   procedure Analyze is
      Success : Boolean;
   begin
      Success := Analyze (Language, AADL_Root);
      if not Success then
         Write_Line ("Cannot analyze AADL specifications");
      else
         Write_Line ("Model analyzed sucessfully");
      end if;
   end Analyze;

   -----------------
   -- Instantiate --
   -----------------

   procedure Instantiate (Root_System : String) is
   begin
      if Root_System /= "" then
         Root_System_Name := To_Lower
           (Get_String_Name (Root_System));
      end if;
      AADL_Root := Instantiate_Model (AADL_Root);
      if Present (AADL_Root) then
         Write_Line ("Model instantiated sucessfully");
      end if;
   end Instantiate;

   --------------
   -- Generate --
   --------------

   procedure Generate (Backend_Name : String) is
   begin
      Set_Current_Backend_Name (Backend_Name);
      Write_Line ("Generating code using backend " & Backend_Name);
      Generate_Code (AADL_Root);
   end Generate;

end Ocarina.Utils;