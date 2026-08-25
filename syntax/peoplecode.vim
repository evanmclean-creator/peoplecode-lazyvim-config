" Vim syntax file
" Language:    PeopleCode (Oracle PeopleSoft / PeopleTools)
" Maintainer:  you
"
" Derived from:
"   - Gideon-Taylor/AppRefiner, PeopleCodeParser.SelfHosted:
"       Lexing/Token.cs, Lexing/PeopleCodeLexer.cs   (token + comment rules)
"       PeopleCodeTypeInfo/typeinfo.dat              (builtin function table,
"       parsed out of the binary hash table: 881 global builtins, 1293
"       %system constants, 73 builtin object types)
"   - Jatz/PeopleSoftTools-vscode PeopleCode.tmLanguage (scope cross-check)
"
" PeopleCode is case-insensitive; the whole file matches case-insensitively.

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syntax case ignore

" Identifier characters, per PeopleCodeLexer.IsIdentifierChar, plus the two
" sigils. Set here rather than relying on the ftplugin's 'iskeyword', so
" highlighting does not depend on which file Neovim sources first. This is
" what stops `syn keyword Record` from firing inside `&record`.
syntax iskeyword @,48-57,_,#,$,&,%

" ---------------------------------------------------------------------------
" Comments -- four flavors, per PeopleCodeLexer
" ---------------------------------------------------------------------------
" Vim rule: when two regions can start at the same column, the one defined
" LAST wins. So the more specific /** must come after the general /*.
syn region peoplecodeComment    start="/\*" end="\*/" contains=peoplecodeTodo,@Spell fold
syn region peoplecodeCommentApi start="/\*\*\%(/\)\@!" end="\*/" contains=peoplecodeTodo,@Spell fold

" <* ... *> genuinely nests (PeopleCodeLexer.ScanNestedComment tracks depth),
" so the region has to contain itself.
syn region peoplecodeCommentNest matchgroup=peoplecodeComment
      \ start="<\*" end="\*>"
      \ contains=peoplecodeCommentNest,peoplecodeTodo,@Spell fold

" REM ... ;  -- terminated by a SEMICOLON, not by end of line, and it may
" legally span lines. PeopleBooks: "Put a semicolon at the end of a REM
" comment. If you do not, everything up to the end of the next statement is
" treated as part of the comment."  Valid at start of line, after ';', or
" after THEN / ELSE (see PeopleCodeLexer.IsInCommentContext).
"
" Only REM is documented by Oracle -- "remark" appears in PeopleBooks solely as
" the parenthetical expansion of the abbreviation. AppRefiner's lexer also
" accepts a literal REMARK, but that is its own leniency, so it is opt-in here:
"   let g:peoplecode_allow_remark = 1
if get(g:, 'peoplecode_allow_remark', 0)
  syn region peoplecodeComment
        \ start="\%(^\|;\|\<then\>\|\<else\>\)\s*\zs\<rem\%(ark\)\=\>"
        \ end=";" contains=peoplecodeTodo,@Spell
else
  syn region peoplecodeComment
        \ start="\%(^\|;\|\<then\>\|\<else\>\)\s*\zs\<rem\>"
        \ end=";" contains=peoplecodeTodo,@Spell
endif

syn keyword peoplecodeTodo TODO FIXME XXX HACK NOTE BUG contained

" /+ ... +/ is NOT a comment: AppRefiner's parser reads real parameter and
" return-type declarations out of it (ParseMethodParameterAnnotation). It gets
" its own group and keeps its contents lit.
syn region peoplecodeAnnotation matchgroup=peoplecodeAnnotationDelim
      \ start="/+" end="+/" keepend
      \ contains=peoplecodeUserVar,peoplecodeType,peoplecodeBuiltinType,
      \          peoplecodeKeyword,peoplecodeStorageClass,peoplecodeOperator

" ---------------------------------------------------------------------------
" Strings -- doubled-quote escaping, single line only
" ---------------------------------------------------------------------------
" How an UNTERMINATED string is rendered. Two defensible behaviours:
"
"   'cascade' (default) -- what App Designer does: the string colour runs to the
"       end of the file until you fix the quote. Loud and unmissable, and it is
"       the behaviour you already have muscle memory for.
"   'error'  -- flag just the offending fragment and leave the rest of the file
"       correctly highlighted. Closer in spirit to App Refiner, which squiggles
"       the remainder rather than recolouring it.
"
"   let g:peoplecode_string_style = 'error'
"
" Note this is purely an editor-ergonomics choice, NOT a claim about the
" language: PeopleCode string literals do not span lines, so either rendering
" is showing you the same underlying mistake.
" `matchgroup=` is load-bearing, not cosmetic. Without it the opening quote is
" part of the region BODY, so the contained +""+ escape match can start on it
" and swallow the closing quote of an empty string -- turning `&x = "";` into an
" unterminated region that colours the rest of the file. matchgroup takes the
" delimiters out of the body, so an escape can only match strictly inside.
syn match peoplecodeStringEsc +""+ contained
syn match peoplecodeStringEsc +''+ contained

if get(g:, 'peoplecode_string_style', 'cascade') ==# 'error'
  " Defined BEFORE the regions so that on a well-formed line the region (later,
  " therefore higher priority at the same column) wins; the error match only
  " surfaces when the region cannot find its closing quote on the line.
  syn match peoplecodeStringError +"\%([^"]\|""\)*$+
  syn match peoplecodeStringError +'\%([^']\|''\)*$+
  syn region peoplecodeString matchgroup=peoplecodeString
        \ start=+"+ skip=+""+ end=+"+ oneline
        \ contains=peoplecodeStringEsc,@Spell
  syn region peoplecodeString matchgroup=peoplecodeString
        \ start=+'+ skip=+''+ end=+'+ oneline
        \ contains=peoplecodeStringEsc,@Spell
else
  syn region peoplecodeString matchgroup=peoplecodeString
        \ start=+"+ skip=+""+ end=+"+
        \ contains=peoplecodeStringEsc,@Spell
  syn region peoplecodeString matchgroup=peoplecodeString
        \ start=+'+ skip=+''+ end=+'+
        \ contains=peoplecodeStringEsc,@Spell
endif

" Interpolated strings:  $"Hello, {&name}!"
syn region peoplecodeInterpString matchgroup=peoplecodeString
      \ start=+\$"+ skip=+""+ end=+"+ oneline
      \ contains=peoplecodeStringEsc,peoplecodeInterp
syn region peoplecodeInterp matchgroup=peoplecodeInterpDelim
      \ start="{" end="}" contained
      \ contains=peoplecodeUserVar,peoplecodeSystemVar,peoplecodeBuiltinFunc,
      \          peoplecodeNumber,peoplecodeBoolean,peoplecodeOperator,
      \          peoplecodeMethodCall,peoplecodeProperty

" ---------------------------------------------------------------------------
" Numbers
" ---------------------------------------------------------------------------
syn match peoplecodeNumber "\<\d\+\>"
syn match peoplecodeNumber "\<\d\+\.\d\+\>"

" ---------------------------------------------------------------------------
" Identifiers
" ---------------------------------------------------------------------------
" &foo is ALWAYS a user variable -- the lexer has no exception to this.
syn match peoplecodeUserVar "&[[:alnum:]_#$]\+"

" Every %Foo is a system variable or system constant. The lexer consults its
" ~80-name table only to pick WHICH of the two subtypes it is, and both are
" read-only builtins, so one regex covers all 1293 names in typeinfo.dat.
syn match peoplecodeSystemVar "%[[:alnum:]_#$]\+"
" %This / %Super behave like self / super. Defined AFTER the general rule:
" when two matches start in the same column, the one defined last wins.
syn match peoplecodeSelf "%\%(this\|super\)\>"

" ^ = App Designer's "current field" shorthand
syn match peoplecodeCaret "\^"

" ---------------------------------------------------------------------------
" Member access:  &rs.GetRow(1).Record.FIELDNAME
" ---------------------------------------------------------------------------
" These are anchored on the DOT, one column left of the member name, so they
" start earlier than -- and therefore outrank -- any `syn keyword` sitting on
" the name itself. Without this, `&rec.Record` paints Record as a type and
" `&msg.Value` paints Value as a keyword.
syn match peoplecodeProperty   "\.\s*[[:alpha:]_][[:alnum:]_#$]*"
      \ contains=peoplecodeDot
syn match peoplecodeMethodCall "\.\s*[[:alpha:]_][[:alnum:]_#$]*\ze\s*("
      \ contains=peoplecodeDot
syn match peoplecodeDot "\." contained

" ---------------------------------------------------------------------------
" Metadata references:  SQL.MY_SQL, Record.PSOPRDEFN, HTML.FOO, ...
" ---------------------------------------------------------------------------
syn match peoplecodeMetaRef
      \ "\<\%(barname\|itemname\|image\|html\|stylesheet\|operation\|filelayout\|businessprocess\|activity\|javaclass\)\.[[:alpha:]_][[:alnum:]_$#]*"
      \ contains=peoplecodeMetaRefKind
syn match peoplecodeMetaRefKind "\<[[:alpha:]]\+\ze\." contained

" ---------------------------------------------------------------------------
" Function calls
" ---------------------------------------------------------------------------
" Any identifier immediately followed by '('. Builtins are `syn keyword`, and a
" keyword outranks a match at the same start column, so this group only ends up
" on user-defined and declared external functions.
syn match peoplecodeFuncCall "\<[[:alpha:]_][[:alnum:]_#$]*\ze\s*("

" Declaration sites
syn match peoplecodeFuncName "\%(\<function\>\s\+\)\@<=[[:alnum:]_#$]\+"
syn match peoplecodeFuncName "\%(\<method\>\s\+\)\@<=[[:alnum:]_#$]\+"
syn match peoplecodeFuncName "\%(\<class\>\s\+\)\@<=[[:alnum:]_#$]\+"
syn match peoplecodeFuncName "\%(\<interface\>\s\+\)\@<=[[:alnum:]_#$]\+"
syn match peoplecodeFuncName "\%(\<property\>\s\+\S\+\s\+\)\@<=[[:alnum:]_#$]\+"

" Application class paths:  UM_ADM:Utils:Helper  (import / extends / As)
syn match peoplecodeAppClass "\<[[:alpha:]_][[:alnum:]_#$]*\%(:[[:alpha:]_][[:alnum:]_#$]*\)\+\%(:\*\)\="

" ---------------------------------------------------------------------------
" Preprocessor / compiler directives
" ---------------------------------------------------------------------------
" Note the hyphen: the lexer's directive table has #END-IF, not "#END IF".
syn match peoplecodePreProc "#\%(if\|then\|else\|end-if\|toolsrel\)\>"
syn match peoplecodePreProcOp "&&\|||"

" ---------------------------------------------------------------------------
" Literals
" ---------------------------------------------------------------------------
syn keyword peoplecodeBoolean True False
syn keyword peoplecodeNull    Null

" ---------------------------------------------------------------------------
" Builtin object types (73, from typeinfo.dat object table)
" ---------------------------------------------------------------------------
syn keyword peoplecodeBuiltinType AnalyticGrid AnalyticInstance AnalyticModel
syn keyword peoplecodeBuiltinType ApiObject Array BIDocs Bindings Chart
syn keyword peoplecodeBuiltinType CompIntfc Compound ContentReference Cookie
syn keyword peoplecodeBuiltinType Crypt CubeCollection Document Field FieldDefn
syn keyword peoplecodeBuiltinType File Folder Gantt Grid GridColumn Hash
syn keyword peoplecodeBuiltinType IBConnectorInfo IBInfo Interlink JavaClass
syn keyword peoplecodeBuiltinType JavaObject Link MCFIMInfo Menu Message
syn keyword peoplecodeBuiltinType Namespaces Node OptEngine OptInterface
syn keyword peoplecodeBuiltinType OrgChart Page Pagelet PortalRegistry
syn keyword peoplecodeBuiltinType PostReport Primitive ProcessRequest
syn keyword peoplecodeBuiltinType PropertyInfo PropertyInfoCollection Query
syn keyword peoplecodeBuiltinType QueryRecord QuerySelect QueryStatistics
syn keyword peoplecodeBuiltinType RatingBoxChart Record RecordDefn
syn keyword peoplecodeBuiltinType RegionalSettings Repository Request Response
syn keyword peoplecodeBuiltinType Row Rowset SQL Scroll SearchQuery Series
syn keyword peoplecodeBuiltinType Session SoapDoc Threshold TraceSettings
syn keyword peoplecodeBuiltinType TransformData Tree TreeLevel TreeNode
syn keyword peoplecodeBuiltinType TreeStructure XmlDoc XmlNode
" ---------------------------------------------------------------------------
" Builtin (global) functions -- 881 System-scope functions from typeinfo.dat.
" `syn keyword` is a hash lookup, not a regex, so the list size costs nothing.
" ---------------------------------------------------------------------------
syn keyword peoplecodeBuiltinFunc Abs AccruableDays AccrualFactor Acos
syn keyword peoplecodeBuiltinFunc ActiveRowCount AddAttachment AddEmailAddress
syn keyword peoplecodeBuiltinFunc AddJavaScript AddKeyListItem AddMetaTag
syn keyword peoplecodeBuiltinFunc AddOnLoadScript AddStyleSheet
syn keyword peoplecodeBuiltinFunc AddSystemPauseTimes AddToDate AddToDateTime
syn keyword peoplecodeBuiltinFunc AddToTime All AllOrNone AllowEmplIdChg
syn keyword peoplecodeBuiltinFunc Americanfxoption Amortize Applicationsrvlog
syn keyword peoplecodeBuiltinFunc Archivereportmgr Asin Atan B76swaption
syn keyword peoplecodeBuiltinFunc Black76call Black76capfloor Black76put
syn keyword peoplecodeBuiltinFunc BlackScholesCall BlackScholesPut
syn keyword peoplecodeBuiltinFunc BootstrapYTMs BPurgeDomainStatus
syn keyword peoplecodeBuiltinFunc Buildcacheproject BulkDeleteField
syn keyword peoplecodeBuiltinFunc BulkInsertField BulkModifyPageFieldOrder
syn keyword peoplecodeBuiltinFunc BulkUpdateIndexes CallAppEngine
syn keyword peoplecodeBuiltinFunc CancelPubHeaderXmlDoc CancelPubXmlDoc
syn keyword peoplecodeBuiltinFunc CancelSubXmlDoc ChangeEmailAddress Char
syn keyword peoplecodeBuiltinFunc CharType ChDir ChDrive CheckMenuItem
syn keyword peoplecodeBuiltinFunc ChunkText Classexists Classextendslist
syn keyword peoplecodeBuiltinFunc Classimplementsbase Clean CleanAttachments
syn keyword peoplecodeBuiltinFunc ClearKeyList ClearSearchDefault
syn keyword peoplecodeBuiltinFunc ClearSearchEdit Clearsearchrecfieldvalues
syn keyword peoplecodeBuiltinFunc Code Codeb CollectGarbage CommitWork
syn keyword peoplecodeBuiltinFunc CompareLikeFields CompareStrings
syn keyword peoplecodeBuiltinFunc CompareTextDiff Comparetoolsrels
syn keyword peoplecodeBuiltinFunc ComponentChanged
syn keyword peoplecodeBuiltinFunc ConfigureClassicPlusComponent
syn keyword peoplecodeBuiltinFunc ConfigureClassicPlusForWC ConnectorRequest
syn keyword peoplecodeBuiltinFunc ConnectorRequestURL ContainsCharType
syn keyword peoplecodeBuiltinFunc ContainsOnlyCharType ConvertChar
syn keyword peoplecodeBuiltinFunc ConvertCurrency ConvertDatetimeToBase
syn keyword peoplecodeBuiltinFunc ConvertRate ConvertTimeToBase CopyAttachments
syn keyword peoplecodeBuiltinFunc CopyFields CopyFromJavaArray CopyRow
syn keyword peoplecodeBuiltinFunc CopyToJavaArray Correlation Cos Cot Count
syn keyword peoplecodeBuiltinFunc Covariance CreateAnalyticInstance CreateArray
syn keyword peoplecodeBuiltinFunc CreateArrayAny CreateArrayRept
syn keyword peoplecodeBuiltinFunc CreateBreadcrumb CreateDirectory
syn keyword peoplecodeBuiltinFunc Createdirecttransferobject CreateDocument
syn keyword peoplecodeBuiltinFunc CreateDocumentKey CreateException
syn keyword peoplecodeBuiltinFunc CreateFieldDefn Createhash Createinmemoryfile
syn keyword peoplecodeBuiltinFunc CreateJavaArray CreateJavaObject
syn keyword peoplecodeBuiltinFunc Createjsonarray CreateJsonBuilder
syn keyword peoplecodeBuiltinFunc Createjsongenerator Createjsonnode
syn keyword peoplecodeBuiltinFunc Createjsonobject CreateJsonParser
syn keyword peoplecodeBuiltinFunc Createjsonvalue Createmcfiminfo CreateMessage
syn keyword peoplecodeBuiltinFunc CreateObject CreateObjectArray
syn keyword peoplecodeBuiltinFunc Createoptengine Createoptinterface
syn keyword peoplecodeBuiltinFunc CreateProcessRequest Createpvgengine
syn keyword peoplecodeBuiltinFunc CreateRecord CreateRecordDefn CreateRowset
syn keyword peoplecodeBuiltinFunc CreateRowsetCache CreateSearchRowset
syn keyword peoplecodeBuiltinFunc Createskinstylesheet CreateSOAPDoc CreateSQL
syn keyword peoplecodeBuiltinFunc CreateWSDLMessage CreateXmlDoc
syn keyword peoplecodeBuiltinFunc CreateXmlDocFactory Createxmllink CropImage
syn keyword peoplecodeBuiltinFunc CubicSpline CurrEffDt CurrEffRowNum
syn keyword peoplecodeBuiltinFunc CurrEffSeq CurrentLevelNumber
syn keyword peoplecodeBuiltinFunc CurrentRowNumber Date3 DatePart DateTime6
syn keyword peoplecodeBuiltinFunc DateTimeToHTTP DateTimeToISO
syn keyword peoplecodeBuiltinFunc DateTimeToLocalizedString DateTimeToTimeZone
syn keyword peoplecodeBuiltinFunc DateTimeToUserFormat DateTimeValue DateValue
syn keyword peoplecodeBuiltinFunc Day Days Days360 Days365 DBCSTrim
syn keyword peoplecodeBuiltinFunc DBPatternMatch DeChunkText Decodetext
syn keyword peoplecodeBuiltinFunc Decodeword Decrypt DecryptStr Degrees
syn keyword peoplecodeBuiltinFunc Deleteagent DeleteAttachment
syn keyword peoplecodeBuiltinFunc DeleteEmailAddress DeleteFieldDefn
syn keyword peoplecodeBuiltinFunc DeleteImage DeleteItem Deletelogq
syn keyword peoplecodeBuiltinFunc Deletemcfcluster Deleteoptprobinst
syn keyword peoplecodeBuiltinFunc Deletephysq DeleteRecord DeleteRecordDefn
syn keyword peoplecodeBuiltinFunc Deleterencluster Deleterenserver DeleteRow
syn keyword peoplecodeBuiltinFunc DeleteSQL DeleteSystemPauseTimes
syn keyword peoplecodeBuiltinFunc Deletethirdpartyagent Deletethirdpartycluster
syn keyword peoplecodeBuiltinFunc Deletethirdpartyq DeQueue DetachAttachment
syn keyword peoplecodeBuiltinFunc DisableMenuItem DiscardRow Distbinomial
syn keyword peoplecodeBuiltinFunc Distchisquared Distlognormal Distnormal
syn keyword peoplecodeBuiltinFunc Distpoisson Distributeq Diststudent
syn keyword peoplecodeBuiltinFunc Doaddsearchaction DoCancel Dochangekeylistnow
syn keyword peoplecodeBuiltinFunc DoesTableExist DoModal DoModalComponent
syn keyword peoplecodeBuiltinFunc DoModalComponentPopup DoModalPanelGroup
syn keyword peoplecodeBuiltinFunc Domodalpanelgrouppopup DoModalPopup Domodals
syn keyword peoplecodeBuiltinFunc Domodalscomponent DoModalX DoModalXComponent
syn keyword peoplecodeBuiltinFunc Domodalxpanelgroup DoSave DoSaveNow
syn keyword peoplecodeBuiltinFunc DownloadToExcel Dumpscroll EnableMenuItem
syn keyword peoplecodeBuiltinFunc EncodeSearchCode Encodetext EncodeURL
syn keyword peoplecodeBuiltinFunc EncodeURLForQueryString Encodeword Encrypt
syn keyword peoplecodeBuiltinFunc Encryptldappswd EncryptNodePswd EncryptStr
syn keyword peoplecodeBuiltinFunc EndMessage EndModal EndModalComponent EnQueue
syn keyword peoplecodeBuiltinFunc EscapeHTML EscapeJavascriptString EscapeWML
syn keyword peoplecodeBuiltinFunc Europeanfxoption Exact Exec
syn keyword peoplecodeBuiltinFunc ExecuteRolePeopleCode ExecuteRoleQuery
syn keyword peoplecodeBuiltinFunc ExecuteRoleWorkflowQuery ExecuteSearchSavePC
syn keyword peoplecodeBuiltinFunc Exp ExpandBindVar ExpandEnvVar ExpandSqlBinds
syn keyword peoplecodeBuiltinFunc Fact FetchSQL FetchValue FieldChanged
syn keyword peoplecodeBuiltinFunc FileExists Filterxsshtml Find Findb
syn keyword peoplecodeBuiltinFunc FindCodeSetValues FindFiles
syn keyword peoplecodeBuiltinFunc Firstinsertwithcommit FlushBulkInserts
syn keyword peoplecodeBuiltinFunc FormatDateTime Forward Forwardrates
syn keyword peoplecodeBuiltinFunc Forwardtask Gamma Gatewayregistration
syn keyword peoplecodeBuiltinFunc GenABNNodeURL GenDynABNElement
syn keyword peoplecodeBuiltinFunc GenerateActGuideContentUrl
syn keyword peoplecodeBuiltinFunc GenerateActGuidePortalUrl
syn keyword peoplecodeBuiltinFunc GenerateActGuideRelativeUrl
syn keyword peoplecodeBuiltinFunc GenerateComponentContentRelURL
syn keyword peoplecodeBuiltinFunc GenerateComponentContentURL
syn keyword peoplecodeBuiltinFunc GenerateComponentPortalRelURL
syn keyword peoplecodeBuiltinFunc GenerateComponentPortalURL
syn keyword peoplecodeBuiltinFunc GenerateComponentRelativeURL
syn keyword peoplecodeBuiltinFunc GenerateExternalPortalURL
syn keyword peoplecodeBuiltinFunc GenerateExternalRelativeURL
syn keyword peoplecodeBuiltinFunc Generatefluidrelatedcontent
syn keyword peoplecodeBuiltinFunc GenerateHomepagePortalURL
syn keyword peoplecodeBuiltinFunc GenerateHomepageRelativeURL GenerateHttpURL
syn keyword peoplecodeBuiltinFunc GenerateMobileTree
syn keyword peoplecodeBuiltinFunc Generatequerycontentexcelurl
syn keyword peoplecodeBuiltinFunc GenerateQueryContentURL
syn keyword peoplecodeBuiltinFunc Generatequerycontentxmlurl
syn keyword peoplecodeBuiltinFunc GenerateQueryPortalURL
syn keyword peoplecodeBuiltinFunc GenerateQueryRelativeURL
syn keyword peoplecodeBuiltinFunc Generatesavewarningjscript
syn keyword peoplecodeBuiltinFunc GenerateScriptContentRelURL
syn keyword peoplecodeBuiltinFunc GenerateScriptContentURL
syn keyword peoplecodeBuiltinFunc GenerateScriptPortalRelURL
syn keyword peoplecodeBuiltinFunc GenerateScriptPortalURL
syn keyword peoplecodeBuiltinFunc GenerateScriptRelativeURL
syn keyword peoplecodeBuiltinFunc Generatetemplateportalurl
syn keyword peoplecodeBuiltinFunc Generatetemplaterelativeurl GenerateTree
syn keyword peoplecodeBuiltinFunc GenerateWorklistPortalURL
syn keyword peoplecodeBuiltinFunc GenerateWorklistRelativeURL GenHTMLMenu
syn keyword peoplecodeBuiltinFunc GenSecureKey Gentimezoneoffsets GenToken
syn keyword peoplecodeBuiltinFunc GetABNChartRowSet GetABNInitialNode
syn keyword peoplecodeBuiltinFunc GetABNNode GetABNRelActnRowSet
syn keyword peoplecodeBuiltinFunc GetABNReqParameters GetABNTreeEffdt
syn keyword peoplecodeBuiltinFunc GetABNTreeName GetABNTreeSetid
syn keyword peoplecodeBuiltinFunc GetABNTreeUserKey Getabsoluterentopic
syn keyword peoplecodeBuiltinFunc Getactivityguideactionitemid
syn keyword peoplecodeBuiltinFunc Getaddbuttonconfiguration
syn keyword peoplecodeBuiltinFunc Getaddcriteriafields Getaddpageinstructions
syn keyword peoplecodeBuiltinFunc Getaddpagelinks Getaddpagetitle
syn keyword peoplecodeBuiltinFunc GetAddSearchRecName Getadvancedoptions
syn keyword peoplecodeBuiltinFunc GetAESection Getagentphysq Getallowactmodesel
syn keyword peoplecodeBuiltinFunc GetAnalyticGrid GetAnalyticGridCreateObject
syn keyword peoplecodeBuiltinFunc GetAnalyticInstance GetArchPubHeaderXmlDoc
syn keyword peoplecodeBuiltinFunc GetArchPubXmlDoc GetArchSubXmlDoc
syn keyword peoplecodeBuiltinFunc GetAttachment GetAttachmentURL
syn keyword peoplecodeBuiltinFunc Getauthorizedsearchgroups
syn keyword peoplecodeBuiltinFunc Getavailablecharsets Getavailableselectors
syn keyword peoplecodeBuiltinFunc Getbasicsearchmode GetBiDoc GetBreadcrumbs
syn keyword peoplecodeBuiltinFunc Getbulkraparamsforpivotgrid
syn keyword peoplecodeBuiltinFunc Getbulkrelatedactions GetCalendarDate
syn keyword peoplecodeBuiltinFunc Getcasesensitivesearch GetChart GetChartURL
syn keyword peoplecodeBuiltinFunc Getcomponentactions GetComponentTitle
syn keyword peoplecodeBuiltinFunc Getcompositequery Getconfigsearchid
syn keyword peoplecodeBuiltinFunc Getcontrol Getcontroloccurrence
syn keyword peoplecodeBuiltinFunc Getcorrecthist Getcqchunkedprocessor
syn keyword peoplecodeBuiltinFunc Getcqruntime Getcrefnavmodes Getcurrenttype
syn keyword peoplecodeBuiltinFunc GetCwd Getdashboardid Getdefaultsearchtype
syn keyword peoplecodeBuiltinFunc GetDefinitionAccess Getdefsmtpconfig
syn keyword peoplecodeBuiltinFunc Getdialgauge GetDNDField GetDNDRow
syn keyword peoplecodeBuiltinFunc GetDNDRowset GetDNDTargetField
syn keyword peoplecodeBuiltinFunc GetDNDTargetRow GetDNDTargetRowset GetEnv
syn keyword peoplecodeBuiltinFunc Geteventmappingreferences
syn keyword peoplecodeBuiltinFunc Getfacetnamestoremove GetField GetFieldDefn
syn keyword peoplecodeBuiltinFunc GetFile Getfiledefnmgr Getfilemetadata
syn keyword peoplecodeBuiltinFunc GetGanttChart GetGaugeThreshold GetGrid
syn keyword peoplecodeBuiltinFunc Getgridcount Gethitcount GetHTMLText
syn keyword peoplecodeBuiltinFunc GetImageExtents Getincludehist GetInterlink
syn keyword peoplecodeBuiltinFunc GetJavaClass Getkeywordsearchtext GetLEDGauge
syn keyword peoplecodeBuiltinFunc GetLevel0 Getmainoptions Getmenustate
syn keyword peoplecodeBuiltinFunc GetMessage GetMessageInstance
syn keyword peoplecodeBuiltinFunc GetMessageXmlDoc GetMethodNames GetNextNumber
syn keyword peoplecodeBuiltinFunc GetNextNumberWithGaps
syn keyword peoplecodeBuiltinFunc GetNextNumberWithGapsCommit
syn keyword peoplecodeBuiltinFunc GetNextProcessInstance Getnextpsrfid
syn keyword peoplecodeBuiltinFunc GetNRXmlDoc Getoptengine Getoptprobinstlist
syn keyword peoplecodeBuiltinFunc GetOrgChart GetPage GetPageField
syn keyword peoplecodeBuiltinFunc GetPagePrefix GetPageTitle GetPageType
syn keyword peoplecodeBuiltinFunc Getpanel GetPanelControlStyle Getppminst
syn keyword peoplecodeBuiltinFunc Getprimaryaction GetProgramFunctionInfo
syn keyword peoplecodeBuiltinFunc Getprogtext Getpromptfieldlabel
syn keyword peoplecodeBuiltinFunc Getpromptlowkeynum Getpromptrelatedcolnum
syn keyword peoplecodeBuiltinFunc Getprompttype GetPubContractInstance
syn keyword peoplecodeBuiltinFunc GetPubHeaderXmlDoc GetPubXmlDoc Getqueueset
syn keyword peoplecodeBuiltinFunc Getrandomphysq GetRatingBoxChart
syn keyword peoplecodeBuiltinFunc GetRatingGauge GetRatingGaugeState GetRecord
syn keyword peoplecodeBuiltinFunc GetRecordDefn GetReferenceArea
syn keyword peoplecodeBuiltinFunc GetReferenceLine Getrelatedactions
syn keyword peoplecodeBuiltinFunc GetRelField Getremovelistview
syn keyword peoplecodeBuiltinFunc Getreportfromrepository GetRow GetRowset
syn keyword peoplecodeBuiltinFunc GetRowsetCache GetRTISwitchThreshold
syn keyword peoplecodeBuiltinFunc Getsearchcategoryname Getsearchcriteria
syn keyword peoplecodeBuiltinFunc Getsearchcriteriafields Getsearchmode
syn keyword peoplecodeBuiltinFunc Getsearchpageinstructions Getsearchpagelinks
syn keyword peoplecodeBuiltinFunc Getsearchpagetitle GetSearchRecordName
syn keyword peoplecodeBuiltinFunc Getsearchresultsfields
syn keyword peoplecodeBuiltinFunc Getsearchresultssortorder
syn keyword peoplecodeBuiltinFunc Getsearchresulttoprow GetSelectedTreeNode
syn keyword peoplecodeBuiltinFunc GetSeries GetSession GetSetId GetSparkChart
syn keyword peoplecodeBuiltinFunc GetSparkChartItem GetSQL GetStatusMeterGauge
syn keyword peoplecodeBuiltinFunc GetStoredFormat GetSubContractInstance
syn keyword peoplecodeBuiltinFunc GetSubXmlDoc GetSyncIBInfoData GetSyncLogData
syn keyword peoplecodeBuiltinFunc GetTempFile Getthirdpartyflag GetThreshold
syn keyword peoplecodeBuiltinFunc GetTimeLine GetToolTip Gettraceoptions
syn keyword peoplecodeBuiltinFunc GetTransactionIDforAE GetTreeNodeParent
syn keyword peoplecodeBuiltinFunc GetTreeNodeRecordName GetTreeNodeValue
syn keyword peoplecodeBuiltinFunc Getumtestname GetURL Getuseinmemorydbflag
syn keyword peoplecodeBuiltinFunc Getuserdata GetUserOption GetWLFieldValue
syn keyword peoplecodeBuiltinFunc Glbalanceasof Glmisc Gltreelookup Gompertz
syn keyword peoplecodeBuiltinFunc Gray GrayMenuItem GroupletRequestSource Hash
syn keyword peoplecodeBuiltinFunc Hashpeoplecode HashSHA256 Hashsql
syn keyword peoplecodeBuiltinFunc HashWithSalt HermiteCubic Hide HideMenuItem
syn keyword peoplecodeBuiltinFunc HideRow HideScroll HistVolatility Hour
syn keyword peoplecodeBuiltinFunc IBPurgeDomainStatus IBPurgeNodesDown Idiv
syn keyword peoplecodeBuiltinFunc InboundPublishXmlDoc Indexagsourceptsf
syn keyword peoplecodeBuiltinFunc InitChat Initexprecfldtbl InsertImage
syn keyword peoplecodeBuiltinFunc InsertItem Insertoptprobinst InsertRow Int
syn keyword peoplecodeBuiltinFunc IsAddEnabled IsAddMode IsAGComponent
syn keyword peoplecodeBuiltinFunc Isagentwithacceptedtask IsAGRequest IsAlpha
syn keyword peoplecodeBuiltinFunc IsAlphaNumeric IsBackEnabled
syn keyword peoplecodeBuiltinFunc IsClassicPlusMode Isconfigurablesearch
syn keyword peoplecodeBuiltinFunc Iscrefconfigured Isdashboarddeployed IsDate
syn keyword peoplecodeBuiltinFunc IsDateTime IsDaylightSavings IsDigits
syn keyword peoplecodeBuiltinFunc Isdisableallactions Isdisconnectedclient
syn keyword peoplecodeBuiltinFunc Isdomainnamevalid IsFluidMode
syn keyword peoplecodeBuiltinFunc IsFluidNotifyEnabled IsFluidSearchStart
syn keyword peoplecodeBuiltinFunc IsGroupletInteractive IsGroupletRequest
syn keyword peoplecodeBuiltinFunc Ishelpenabled IsHidden IsHomeEnabled
syn keyword peoplecodeBuiltinFunc IsIScriptAuthorized IsLogoutEnabled
syn keyword peoplecodeBuiltinFunc IsMDAJAXTrf IsMDComponent IsMDGuided
syn keyword peoplecodeBuiltinFunc Ismdlistaccordion IsMDListPopup
syn keyword peoplecodeBuiltinFunc IsMDListSlideout IsMDNonOptimized IsMDRequest
syn keyword peoplecodeBuiltinFunc IsMDSearchEnabled IsMenuItemAuthorized
syn keyword peoplecodeBuiltinFunc IsMessageActive IsModal IsModalComponent
syn keyword peoplecodeBuiltinFunc IsModalPanelGroup IsModeless IsNavBarEnabled
syn keyword peoplecodeBuiltinFunc IsNewWindowEnabled IsNextInListEnabled
syn keyword peoplecodeBuiltinFunc IsNotificationEnabled IsNotifyEnabled
syn keyword peoplecodeBuiltinFunc IsNumber IsOperatorInClass ISOToDate
syn keyword peoplecodeBuiltinFunc ISOToDateTime Isototime
syn keyword peoplecodeBuiltinFunc IsPIIandSensitiveForUser IsPinEnabled
syn keyword peoplecodeBuiltinFunc IsPrevInListEnabled Isqwithacceptedtask
syn keyword peoplecodeBuiltinFunc Isrcforfluidenabled IsRecFieldPII
syn keyword peoplecodeBuiltinFunc IsRecFieldSensitive
syn keyword peoplecodeBuiltinFunc Isrelatedactionsconfigured
syn keyword peoplecodeBuiltinFunc Isrelatedactionsconfiguredext
syn keyword peoplecodeBuiltinFunc IsReturnToListEnabled Isrtienabled
syn keyword peoplecodeBuiltinFunc Isrtienabledsearchdefinition IsSaveEnabled
syn keyword peoplecodeBuiltinFunc IsSearchDialog IsSearchEnabled
syn keyword peoplecodeBuiltinFunc IsSingleComponentAG IsSingleUnitOfWork
syn keyword peoplecodeBuiltinFunc IsSmallFFOptimized Issmtpserveravailable
syn keyword peoplecodeBuiltinFunc IsStandardSearchEnabled IsTime
syn keyword peoplecodeBuiltinFunc IsUserInPermissionList IsUserInRole
syn keyword peoplecodeBuiltinFunc IsUserNumber Isvalidoptprobinst Left Len Lenb
syn keyword peoplecodeBuiltinFunc LinearInterp Linearsolution Ln Lngamma
syn keyword peoplecodeBuiltinFunc LoadABN Log10 Logevent LogObjectUse Lower
syn keyword peoplecodeBuiltinFunc LTrim MAddAttachment Mapciaction
syn keyword peoplecodeBuiltinFunc MarkPrimaryEmailAddress MarkWLItemWorked Max
syn keyword peoplecodeBuiltinFunc MCFBroadcast Mcfserverrefresh MessageBox
syn keyword peoplecodeBuiltinFunc Mgetfilemetadata Min Minute Mod Month
syn keyword peoplecodeBuiltinFunc Mputattachment Msfgetnextnumber
syn keyword peoplecodeBuiltinFunc MsgBoxButtonOverride MsgGet MsgGetExplainText
syn keyword peoplecodeBuiltinFunc MsgGetText NextEffDt NextRelEffDt NodeDelete
syn keyword peoplecodeBuiltinFunc NodeRename NodeSaveAs NodeTranDelete None
syn keyword peoplecodeBuiltinFunc Notifyagentshutdown Notifyclustershutdown
syn keyword peoplecodeBuiltinFunc Notifynewq NotifyQ Notifyqshutdown
syn keyword peoplecodeBuiltinFunc NumberToDisplayString NumberToString
syn keyword peoplecodeBuiltinFunc Numofacceptedtaskforagent
syn keyword peoplecodeBuiltinFunc Numofacceptedtaskforphysq Numofagentsonphysq
syn keyword peoplecodeBuiltinFunc Numofassignedtaskforphysq
syn keyword peoplecodeBuiltinFunc Numofenqueuedtaskforphysq ObjectDoMethod
syn keyword peoplecodeBuiltinFunc ObjectDoMethodArray ObjectGetProperty
syn keyword peoplecodeBuiltinFunc ObjectSetProperty Objexpdomethod
syn keyword peoplecodeBuiltinFunc Objexpgetproperty Objexpsetproperty OnlyOne
syn keyword peoplecodeBuiltinFunc OnlyOneOrNone OverrideCNAVDisplayMode
syn keyword peoplecodeBuiltinFunc OverrideConditionalNav PanelGroupChanged
syn keyword peoplecodeBuiltinFunc Parsequeryexpression PingNode Postqasreport
syn keyword peoplecodeBuiltinFunc PreloadCache PriorEffDt PriorRelEffDt
syn keyword peoplecodeBuiltinFunc PriorValue Processrecurrence Product Prompt
syn keyword peoplecodeBuiltinFunc Proper Prunellm Psgetsystemvar
syn keyword peoplecodeBuiltinFunc Psgwrequestproperties Psigwservicerequest
syn keyword peoplecodeBuiltinFunc Publishtoren PublishXmlDoc Purgeboereports
syn keyword peoplecodeBuiltinFunc Purgeprocessrequest Purgeqasdata
syn keyword peoplecodeBuiltinFunc Purgeschdlrserver PutAttachment Quote Radians
syn keyword peoplecodeBuiltinFunc Rand ReadFileStream
syn keyword peoplecodeBuiltinFunc Reassignacceptedtaskonphysq RecordChanged
syn keyword peoplecodeBuiltinFunc RecordDeleted RecordNew RefreshTree
syn keyword peoplecodeBuiltinFunc RelNodeTranDelete RemoteCall RemoveDirectory
syn keyword peoplecodeBuiltinFunc RenameDBField RenamePage RenameRecord Replace
syn keyword peoplecodeBuiltinFunc Rept ResizeImage Resolvemetasql
syn keyword peoplecodeBuiltinFunc ReSubmitPubHeaderXmlDoc ReSubmitPubXmlDoc
syn keyword peoplecodeBuiltinFunc ReSubmitSubXmlDoc ReturnToServer
syn keyword peoplecodeBuiltinFunc ReValidateNRXmlDoc RevalidatePassword Right
syn keyword peoplecodeBuiltinFunc Round RoundCurrency RowCount RowFlush
syn keyword peoplecodeBuiltinFunc RowScrollSelect RowScrollSelectNew
syn keyword peoplecodeBuiltinFunc Rptnodevalidate RTrim Runcontrolmanager
syn keyword peoplecodeBuiltinFunc SamRefreshView ScanFile Schaeferschwartz
syn keyword peoplecodeBuiltinFunc ScheduleProcess ScrollFlush ScrollSelect
syn keyword peoplecodeBuiltinFunc ScrollSelectNew Second SecureRandomGen
syn keyword peoplecodeBuiltinFunc Sendagitemstorti Sendallmcfemails SendMail
syn keyword peoplecodeBuiltinFunc Sendmcfemail Sendtextmsg Servertest
syn keyword peoplecodeBuiltinFunc Setactionurl SetAddMode
syn keyword peoplecodeBuiltinFunc SetAuthenticationResult Setbasicsearchmode
syn keyword peoplecodeBuiltinFunc Setcasesensitivesearch SetChannelStatus
syn keyword peoplecodeBuiltinFunc SetComponentChanged SetControlValue
syn keyword peoplecodeBuiltinFunc Setcorrecthist Setcrmtext SetCursorPos
syn keyword peoplecodeBuiltinFunc SetDBFieldAuxFlag SetDBFieldCharDefn
syn keyword peoplecodeBuiltinFunc SetDBFieldFormat SetDBFieldFormatLength
syn keyword peoplecodeBuiltinFunc SetDBFieldLabel SetDBFieldLength
syn keyword peoplecodeBuiltinFunc SetDBFieldNotUsed SetDefault SetDefaultAll
syn keyword peoplecodeBuiltinFunc SetDefaultNext SetDefaultNextRel
syn keyword peoplecodeBuiltinFunc SetDefaultPrior SetDefaultPriorRel
syn keyword peoplecodeBuiltinFunc SetDisplayFormat SetFacetNamesToRemove
syn keyword peoplecodeBuiltinFunc Setincludehist Setkeywordsearchtext SetLabel
syn keyword peoplecodeBuiltinFunc SetLanguage Setlastupdoprid SetMDAJAXTrf
syn keyword peoplecodeBuiltinFunc SetMDGuided Setmdlistaccordion SetMDListPopup
syn keyword peoplecodeBuiltinFunc SetMDListSlideout SetMessageStatus
syn keyword peoplecodeBuiltinFunc Setnavcolltype SetNextPage SetNextPanel
syn keyword peoplecodeBuiltinFunc SetPageFieldPageFieldName Setpagetype
syn keyword peoplecodeBuiltinFunc SetPanelControlStyle SetPasswordExpired
syn keyword peoplecodeBuiltinFunc Setpopupmenuoptions Setportlettitle
syn keyword peoplecodeBuiltinFunc SetPostReport Setqueuestatus
syn keyword peoplecodeBuiltinFunc SetRecFieldEditTable SetRecFieldKey SetReEdit
syn keyword peoplecodeBuiltinFunc SetRemovelistView Setrenderurl Setresourceurl
syn keyword peoplecodeBuiltinFunc SetSaveWarningFilter Setscreenreadermode
syn keyword peoplecodeBuiltinFunc SetSearchDefault SetSearchDialogBehavior
syn keyword peoplecodeBuiltinFunc SetSearchEdit Setsearchmode Setsearchrowset
syn keyword peoplecodeBuiltinFunc Setsinglecomponentag Setsingleunitofwork
syn keyword peoplecodeBuiltinFunc SetTempTableInstance SetThemeId Settracepage
syn keyword peoplecodeBuiltinFunc Settracepanel SetTracePC SetTraceSQL
syn keyword peoplecodeBuiltinFunc SetTransferAttributes Setumtestname
syn keyword peoplecodeBuiltinFunc SetupScheduleDefnItem Setuseinmemorydbflag
syn keyword peoplecodeBuiltinFunc SetUserOption ShareAttachment
syn keyword peoplecodeBuiltinFunc ShouldSuppressCREF Sign Sin SinglePaymentPV
syn keyword peoplecodeBuiltinFunc Slavetemplqueuenames SortScroll Split SQLExec
syn keyword peoplecodeBuiltinFunc Sqrt StartWork Stepfninterp StopFetching
syn keyword peoplecodeBuiltinFunc StoreSQL StripOffHTMLTags Substitute
syn keyword peoplecodeBuiltinFunc Substring Substringb Switchtostandardsearch
syn keyword peoplecodeBuiltinFunc SwitchUser SyncRequestXmlDoc Syncxlattbl
syn keyword peoplecodeBuiltinFunc Tablelookup Tan Time3 TimePart Timetoiso
syn keyword peoplecodeBuiltinFunc TimeToTimeZone TimeValue TimeZoneOffset
syn keyword peoplecodeBuiltinFunc TotalRowCount Transfer Transferagentsphysq
syn keyword peoplecodeBuiltinFunc TransferExact TransferExactTop
syn keyword peoplecodeBuiltinFunc TransferMobilePage TransferModeless
syn keyword peoplecodeBuiltinFunc TransferNode TransferPage TransferPanel
syn keyword peoplecodeBuiltinFunc Transferphysq TransferPortal TransferTop
syn keyword peoplecodeBuiltinFunc Transform TransformEx TransformExCache
syn keyword peoplecodeBuiltinFunc TreeDetailInNode Treesavecomplete
syn keyword peoplecodeBuiltinFunc TriggerBusinessEvent Trimtoolsrel Truncate
syn keyword peoplecodeBuiltinFunc TurnOffRTI TurnOffRTIFromProcess Turnonrti
syn keyword peoplecodeBuiltinFunc UIDisplayMode UnCheckMenuItem Unencode UnGray
syn keyword peoplecodeBuiltinFunc UnHide UnhideRow UnhideScroll UniformSeriesPV
syn keyword peoplecodeBuiltinFunc UnshareAttachment UpdateJSMetadata
syn keyword peoplecodeBuiltinFunc Updateslavetemplqueue UpdateSysVersion
syn keyword peoplecodeBuiltinFunc UpdateValue UpdateXmlDoc Uploadtogrid Upper
syn keyword peoplecodeBuiltinFunc Uuidgen Uuidgenbase64 Validateemailaddress
syn keyword peoplecodeBuiltinFunc Validategroup Validaterenserver ValueUser
syn keyword peoplecodeBuiltinFunc VerifyHash VerifyOprPassword ViewAttachment
syn keyword peoplecodeBuiltinFunc ViewContentURL ViewContentURLClassic
syn keyword peoplecodeBuiltinFunc ViewContentURLFluid ViewContentURLModeless
syn keyword peoplecodeBuiltinFunc ViewURL ViewURLModeless ViewURLTop Weekday
syn keyword peoplecodeBuiltinFunc WinEscape WinExec WinMessage WriteToLog
syn keyword peoplecodeBuiltinFunc Wssecisauthenticateduser
syn keyword peoplecodeBuiltinFunc Wssecisauthforwsoperation Wssecisvaliduser
syn keyword peoplecodeBuiltinFunc Year

" ---------------------------------------------------------------------------
" Primitive types
" ---------------------------------------------------------------------------
syn keyword peoplecodeType any boolean date datetime exception float integer
syn keyword peoplecodeType number string time
syn match   peoplecodeType "\<array[2-9]\=\>"

" ---------------------------------------------------------------------------
" Storage / access modifiers
" ---------------------------------------------------------------------------
syn keyword peoplecodeStorageClass abstract private protected public readonly
syn keyword peoplecodeStorageClass instance global local constant component
syn keyword peoplecodeStorageClass componentlife panelgroup out ref value alias
syn keyword peoplecodeStorageClass library static

" ---------------------------------------------------------------------------
" Declarations / structure
" ---------------------------------------------------------------------------
syn keyword peoplecodeKeyword declare import extends implements property create
syn keyword peoplecodeKeyword doc peoplecode
" Hyphenated block keywords are single tokens with EXACTLY one hyphen and no
" spaces (PeopleCodeLexer.ScanEndKeyword rejects "End Class" and "End - Class"),
" so they are matched as literal hyphenated strings.
syn match peoplecodeKeyword "\<class\>"
syn match peoplecodeKeyword "\<end-class\>"
syn match peoplecodeKeyword "\<interface\>"
syn match peoplecodeKeyword "\<end-interface\>"
syn match peoplecodeKeyword "\<method\>"
syn match peoplecodeKeyword "\<end-method\>"
syn match peoplecodeKeyword "\<function\>"
syn match peoplecodeKeyword "\<end-function\>"
syn match peoplecodeKeyword "\<get\>"
syn match peoplecodeKeyword "\<end-get\>"
syn match peoplecodeKeyword "\<set\>"
syn match peoplecodeKeyword "\<end-set\>"

" ---------------------------------------------------------------------------
" Control flow
" ---------------------------------------------------------------------------
syn keyword peoplecodeConditional if then else
syn match   peoplecodeConditional "\<end-if\>"

syn keyword peoplecodeRepeat for to step until while repeat
syn match   peoplecodeRepeat "\<end-for\>"
syn match   peoplecodeRepeat "\<end-while\>"

syn keyword peoplecodeLabel evaluate when
syn match   peoplecodeLabel "\<when-other\>"
syn match   peoplecodeLabel "\<end-evaluate\>"

syn keyword peoplecodeException try catch throw error warning
syn match   peoplecodeException "\<end-try\>"

syn keyword peoplecodeStatement break continue exit return returns

" ---------------------------------------------------------------------------
" Operators
" ---------------------------------------------------------------------------
syn keyword peoplecodeOperator and or not
syn keyword peoplecodeKeyword  as of
" One alternation instead of 16 separate matches: Vim's regex engine is
" leftmost-longest within a single pattern, so ** beats *, <= beats <, and so
" on, with no ordering games and no lookahead needed to protect the comment
" openers (those regions are matched at an earlier or equal column and win).
" The '<' and '/' alternatives carry negative lookaheads because operators are
" defined last in this file and would otherwise outrank the comment regions
" that start in the same column.
syn match peoplecodeOperator "\*\*\|<>\|!=\|<=\|>=\|+=\|-=\||=\|[-+*=>|@]"
syn match peoplecodeOperator "<\%(\*\)\@!"
syn match peoplecodeOperator "/\%([*+]\)\@!"

" ---------------------------------------------------------------------------
" Record-field events, and [Section] markers from "Save PeopleCode to File"
" ---------------------------------------------------------------------------
syn keyword peoplecodeRecordEvent FieldDefault FieldEdit FieldChange FieldFormula
syn keyword peoplecodeRecordEvent RowInit RowInsert RowDelete RowSelect
syn keyword peoplecodeRecordEvent SaveEdit SavePreChange SavePostChange
syn keyword peoplecodeRecordEvent SearchInit SearchSave Workflow PrePopup
syn match peoplecodeEventMarker "^\[[^]]\+\]$"

" ---------------------------------------------------------------------------
" Highlight links
" ---------------------------------------------------------------------------
" This is the part that actually fixes the "everything is the same purple"
" problem. Linking to Vim's classic groups is not enough: in Tokyo Night (and
" catppuccin, kanagawa, rose-pine, ...) `Identifier` is linked to the SAME
" magenta as `Keyword`, so `&myVar` and `If` come out byte-identical. The
" Tree-sitter capture groups are the ones modern colorschemes actually style
" apart, and Neovim lets a legacy syntax file link straight to them.
function! s:Link(from, to, fallback) abort
  if hlexists(a:to)
    execute 'hi def link' a:from a:to
  else
    execute 'hi def link' a:from a:fallback
  endif
endfunction

call s:Link('peoplecodeUserVar',       '@variable',           'Identifier')
call s:Link('peoplecodeSystemVar',     '@constant.builtin',   'Constant')
call s:Link('peoplecodeSelf',          '@variable.builtin',   'Statement')
call s:Link('peoplecodeBuiltinFunc',   '@function.builtin',   'Function')
call s:Link('peoplecodeFuncCall',      '@function.call',      'Function')
call s:Link('peoplecodeFuncName',      '@function',           'Function')
call s:Link('peoplecodeMethodCall',    '@function.method.call', 'Function')
call s:Link('peoplecodeProperty',      '@property',           'Identifier')
call s:Link('peoplecodeDot',           '@punctuation.delimiter', 'Delimiter')
call s:Link('peoplecodeBuiltinType',   '@type.builtin',       'Type')
call s:Link('peoplecodeType',          '@type.builtin',       'Type')
call s:Link('peoplecodeStringEsc',     '@string.escape',      'SpecialChar')
call s:Link('peoplecodeAppClass',      '@module',             'Type')
call s:Link('peoplecodeMetaRefKind',   '@module',             'Type')
call s:Link('peoplecodeMetaRef',       '@constant',           'Constant')
call s:Link('peoplecodeInterpDelim',   '@punctuation.special', 'Special')
call s:Link('peoplecodeAnnotation',    '@attribute',          'PreProc')
call s:Link('peoplecodeAnnotationDelim', '@punctuation.special', 'PreProc')
call s:Link('peoplecodeCommentApi',    '@comment.documentation', 'SpecialComment')
call s:Link('peoplecodeRecordEvent',   '@function',           'Special')
call s:Link('peoplecodeCaret',         '@variable.builtin',   'Special')

hi def link peoplecodeComment      Comment
hi def link peoplecodeCommentNest  Comment
hi def link peoplecodeTodo         Todo
hi def link peoplecodeString       String
hi def link peoplecodeInterpString String
hi def link peoplecodeNumber       Number
hi def link peoplecodeBoolean      Boolean
hi def link peoplecodeNull         Constant
hi def link peoplecodeStorageClass StorageClass
hi def link peoplecodeKeyword      Keyword
hi def link peoplecodeConditional  Conditional
hi def link peoplecodeRepeat       Repeat
hi def link peoplecodeLabel        Label
hi def link peoplecodeException    Exception
hi def link peoplecodeStatement    Statement
hi def link peoplecodeOperator     Operator
hi def link peoplecodePreProc      PreCondit
hi def link peoplecodePreProcOp    PreCondit
hi def link peoplecodeEventMarker  Title

delfunction s:Link

hi def link peoplecodeStringError  Error

" Multi-line constructs (REM ... ; , <* *> , and a cascading unterminated
" string) mean Vim cannot correctly colour a screenful by looking only at the
" visible lines. Without this, scrolling into the middle of a large file
" mis-highlights until you redraw from the top.
exe 'syn sync minlines=' . get(g:, 'peoplecode_sync_minlines', 300)

let b:current_syntax = "peoplecode"

let &cpo = s:cpo_save
unlet s:cpo_save