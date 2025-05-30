import { systemDateTime } from '@kit.BasicServicesKit';
import { otpType, TokenConfig } from '../utils/TokenConfig';
import { copyText, generateOTP } from '../utils/TokenUtils';
import { TokenIcon } from './TokenIcon';
import { SteamUtils } from '../utils/SteamUtils';
import { AppPreference, TokenPreference } from '../utils/AppPreference';
import { AppStorageV2 } from '@kit.ArkUI';

let current_token_hide_map: Map<string, boolean> = new Map();

@Preview
@ComponentV2
export struct TokenItem {
  @Require @Param Config: TokenConfig = new TokenConfig();
  @Event Update: (conf: TokenConfig) => void = () => {};

  @Local token_preference: TokenPreference = AppStorageV2.connect(TokenPreference) as TokenPreference;

  @Local TokenNumber: string = '000000';
  @Local TokenNumberNext: string = '000000';
  @Local TokenCounter: string = '0';
  @Local TokenLeftPeriod: number = 0;
  @Local btn_hotp_clicked: number = 0;
  @Local TokenHide: boolean = current_token_hide_map[this.Config.TokenUUID] ?? true;

  private token_steps: number = 0;
  private token_color_change_threshold = 5;
  private token_progress_color_normal: LinearGradient = new LinearGradient(
    [
      {color: $r('app.color.token_progress_normal_color_start'), offset: 0},
      {color: $r('app.color.token_progress_normal_color_end'), offset: 1},
    ])
  private token_progress_color_near_next: LinearGradient = new LinearGradient(
    [
      {color: $r('app.color.token_progress_next_color_start'), offset: 0},
      {color: $r('app.color.token_progress_next_color_end'), offset: 1},
    ])

  aboutToAppear(): void {
    getContext(this).eventHub.on('onTimestampChanged', (timestamp: number, force: boolean) => this.onTimestampChanged(timestamp, force));
    this.updateToken();
  }

  onTimestampChanged(timestamp: number, force: boolean): void {
    if (this.Config.TokenType !== otpType.HOTP) {
      this.token_steps = Math.floor(timestamp / this.Config.TokenPeriod);
      this.TokenLeftPeriod = this.Config.TokenPeriod - timestamp % this.Config.TokenPeriod;
      if (this.TokenLeftPeriod == this.Config.TokenPeriod || force) {
        this.updateTOTPToken();
      }
    }
  }

  updateToken() {
    if (this.Config === undefined) {
      return;
    }
    if (this.Config.TokenType == otpType.HOTP) {
      this.updateHOTPToken();
    } else {
      const timestamp = Math.floor(systemDateTime.getTime() / 1000);
      this.onTimestampChanged(timestamp, true);
    }
  }

  updateHOTPToken() {
    this.TokenCounter = this.Config.TokenCounter.toString();
    this.TokenNumber = generateOTP(this.Config, this.Config.TokenCounter).toString().padStart(this.Config.TokenDigits, '0');
    this.TokenNumberNext = generateOTP(this.Config, this.Config.TokenCounter + 1).toString().padStart(this.Config.TokenDigits, '0');
  }

  updateTOTPToken() {
    let int_code = generateOTP(this.Config, this.token_steps);
    let int_code_next = generateOTP(this.Config, this.token_steps + 1);
    if (this.Config.TokenType === otpType.Steam) {
      this.TokenNumber = SteamUtils.SteamTokenFromTOTP(int_code);
      this.TokenNumberNext = SteamUtils.SteamTokenFromTOTP(int_code_next);
    } else {
      this.TokenNumber = int_code.toString().padStart(this.Config.TokenDigits, '0');
      this.TokenNumberNext = int_code_next.toString().padStart(this.Config.TokenDigits, '0');
    }
  }

  build() {
    Row({ space: 10 }) {
      TokenIcon({ issuer: this.Config.TokenIssuer, icon_path: this.Config.TokenIconPath })
      Column() {
        Text(this.token_preference.app_appearance_swap_host_user_enable ? this.Config.TokenName : this.Config.TokenIssuer)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .maxLines(1)
          .fontSize(this.token_preference.app_appearance_issuer_font_size)
          .fontWeight(this.token_preference.app_appearance_issuer_font_weight)
          .fontColor($r('app.color.str_main'))
        Text(this.token_preference.app_appearance_swap_host_user_enable ? this.Config.TokenIssuer : this.Config.TokenName)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .maxLines(1)
          .fontSize(this.token_preference.app_appearance_user_name_font_size)
          .fontWeight(this.token_preference.app_appearance_user_name_font_weight)
          .fontColor($r('app.color.str_gray'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Blank()

      if (AppPreference.getPreference('app_debug_mode_on')) {
        Text(this.Config.RankScore.toString())
          .textAlign(TextAlign.Center)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .maxLines(1)
          .fontSize(30)
      }

      if (this.TokenHide && this.token_preference.app_safety_hide_token_enable) {
        Stack() {
          Text() {
            Span("●●●●")
          }
          .fontColor(Color.Gray)
          .fontSize(this.token_preference.app_appearance_token_font_size)
        }
        .onClick(() => {
          this.TokenHide = !this.TokenHide;
          current_token_hide_map[this.Config.TokenUUID] = false;
        })

      } else {
        Column() {
          Text(this.TokenNumber)
            .textAlign(TextAlign.End)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
            .maxLines(1)
            .fontColor(this.TokenLeftPeriod <= this.token_color_change_threshold && this.Config.TokenType !== otpType.HOTP ?
              $r('app.color.token_progress_next_color_end') :
              $r('app.color.token_number'))
            .fontSize(this.token_preference.app_appearance_token_font_size)
            .fontWeight(this.token_preference.app_appearance_token_font_weight)
            .gesture(
              LongPressGesture()
                .onAction(() => {
                  copyText(this.TokenNumber, `token ${this.TokenNumber} `+ getContext(this).resourceManager.getStringSync($r('app.string.token_copied')).toString());
                })
            )
          if (this.Config.TokenType == otpType.HOTP) {
            Text(this.TokenCounter + (this.token_preference.app_appearance_show_next_token_enable ? ":" + this.TokenNumberNext : ""))
              .textAlign(TextAlign.End)
              .textOverflow({ overflow: TextOverflow.MARQUEE })
              .maxLines(1)
              .fontColor($r('app.color.str_gray'))
              .fontSize(10)
          } else if (this.token_preference.app_appearance_show_next_token_enable) {
            Text(this.TokenNumberNext)
              .textAlign(TextAlign.End)
              .textOverflow({ overflow: TextOverflow.MARQUEE })
              .maxLines(1)
              .fontColor($r('app.color.str_gray'))
              .fontSize(10)
          }
        }
        .onClick(() => {
          if (this.token_preference.app_safety_hide_token_enable) {
            this.TokenHide = !this.TokenHide;
            current_token_hide_map[this.Config.TokenUUID] = true;
          }
        })

        if (this.Config.TokenType == otpType.HOTP) {
          SymbolGlyph($r('sys.symbol.lock_filled_arrow_counterclockwise'))
            .fontColor([$r('app.color.token_number')])
            .fontSize(40)
            .fontWeight(FontWeight.Medium)
            .symbolEffect(new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.UP),
              this.btn_hotp_clicked)
            .onClick(() => {
              this.btn_hotp_clicked++;
              this.Config.TokenCounter++;
              this.Update(this.Config)
              this.updateHOTPToken();
            })
        } else {
          Stack() {
            Text(this.TokenLeftPeriod.toString())
            Progress({ value: this.TokenLeftPeriod, total: this.Config.TokenPeriod, type: ProgressType.Ring })
              .style({ strokeWidth: 8 })
              .width(40)
              .height(40)
              .color(this.TokenLeftPeriod <= this.token_color_change_threshold ?
                this.token_progress_color_near_next :
                this.token_progress_color_normal)
          }
        }
      }
    }
    .borderRadius(10)
    .shadow({ radius: 10, color: $r('app.color.shadow'), offsetX: 10, offsetY: 10 })
    .padding(10)
    .justifyContent(FlexAlign.SpaceBetween)
    .width('100%')
    .height(this.token_preference.app_appearance_item_height)
    .backgroundColor($r("app.color.item_bg"))
  }
}
