import pandas as pd
import numpy as np
import re

def clean_team_name(team):
    """Clean team names to match between datasets - use abbreviated names"""
    team = str(team).strip()
    team_mapping = {
        'KC': 'KC','BUF': 'BUF','CIN': 'CIN','JAX': 'JAX','SF': 'SF','LAC': 'LAC','BAL': 'BAL','PHI': 'PHI','DAL': 'DAL','ARI': 'ARI',
        'CLE': 'CLE','NYG': 'NYG','TB': 'TB','MIN': 'MIN','DET': 'DET','GB': 'GB','ATL': 'ATL','IND': 'IND','TEN': 'TEN','NYJ': 'NYJ',
        'DEN': 'DEN','LV': 'LV','NE': 'NE','CHI': 'CHI','HOU': 'HOU','PIT': 'PIT','WAS': 'WAS','SEA': 'SEA','LAR': 'LAR','MIA': 'MIA','CAR': 'CAR'
    }
    return team_mapping.get(team, team)

def clean_test_team_name(team):
    """Clean team names from test data to match contract team names"""
    team = str(team).strip()
    team_mapping = {
        'Cincinnati Bengals': 'CIN','Buffalo Bills': 'BUF','Minnesota Vikings': 'MIN','Baltimore Ravens': 'BAL','Philadelphia Eagles': 'PHI',
        'Cleveland Browns': 'CLE','Dallas Cowboys': 'DAL','San Francisco 49ers': 'SF','Kansas City Chiefs': 'KC','New York N Giants': 'NYG',
        'Tampa Bay Buccaneers': 'TB','Detroit Lions': 'DET','Green Bay Packers': 'GB','Atlanta Falcons': 'ATL','Indianapolis Colts': 'IND',
        'Tennessee Titans': 'TEN','New York A Jets': 'NYJ','Denver Broncos': 'DEN','Las Vegas Raiders': 'LV','New England Patriots': 'NE',
        'Chicago Bears': 'CHI','Houston Texans': 'HOU','Pittsburgh Steelers': 'PIT','Washington Commanders': 'WAS','Seattle Seahawks': 'SEA',
        'Los Angeles N Rams': 'LAR','Miami Dolphins': 'MIA','Carolina Panthers': 'CAR','Los Angeles A Chargers': 'LAC','Arizona Cardinals': 'ARI'
    }
    return team_mapping.get(team, team)

def clean_pfl_team_name(team):
    """Clean team names from PFL data to match test data format"""
    team = str(team).strip()
    team_mapping = {
        'Cincinnati': 'Cincinnati Bengals','Buffalo': 'Buffalo Bills','Minnesota': 'Minnesota Vikings','Baltimore': 'Baltimore Ravens',
        'Philadelphia': 'Philadelphia Eagles','Cleveland': 'Cleveland Browns','Dallas': 'Dallas Cowboys','San Francisco': 'San Francisco 49ers',
        'Kansas City': 'Kansas City Chiefs','New York N': 'New York N Giants','Tampa Bay': 'Tampa Bay Buccaneers','Detroit': 'Detroit Lions',
        'Green Bay': 'Green Bay Packers','Atlanta': 'Atlanta Falcons','Indianapolis': 'Indianapolis Colts','Tennessee': 'Tennessee Titans',
        'New York A': 'New York A Jets','Denver': 'Denver Broncos','Las Vegas': 'Las Vegas Raiders','New England': 'New England Patriots',
        'Chicago': 'Chicago Bears','Houston': 'Houston Texans','Pittsburgh': 'Pittsburgh Steelers','Washington': 'Washington Commanders',
        'Seattle': 'Seattle Seahawks','Los Angeles N': 'Los Angeles N Rams','Miami': 'Miami Dolphins','Carolina': 'Carolina Panthers',
        'Los Angeles A': 'Los Angeles A Chargers','Arizona': 'Arizona Cardinals'
    }
    return team_mapping.get(team, team)

def normalize_name(name: str) -> str:
    """Lowercase, remove spaces/punct, and drop suffixes like Jr., III, II."""
    if pd.isna(name):
        return ''
    s = str(name).lower()
    s = s.replace("'", '').replace('-', '').replace('.', '').replace(' ', '')
    # Remove common suffixes
    for suf in ['jr', 'sr', 'ii', 'iii', 'iv', 'v']:
        if s.endswith(suf):
            s = s[: -len(suf)]
            break
    return s

def normalize_pos_generic(pos: str) -> str:
    """Map various labels to a canonical position set to improve joins."""
    if pd.isna(pos):
        return ''
    p = str(pos).upper().strip()
    mapping = {
        # Defensive front
        'LE': 'DE','RE': 'DE','DE': 'DE',
        'DT': 'DT',
        # Linebackers
        'MLB': 'ILB','ILB': 'ILB','OLB': 'OLB',
        # Secondary
        'FS': 'S','SS': 'S','S': 'S','CB': 'CB',
        # OL
        'LT': 'LT','RT': 'RT','LG': 'G','RG': 'G','G': 'G','C': 'C',
        # Skill offense
        'HB': 'RB','RB': 'RB','WR': 'WR','TE': 'TE','QB': 'QB'
    }
    return mapping.get(p, p)

def extract_contract_value(contract_str):
    """Extract numeric value from currency string (returns raw dollars)."""
    if pd.isna(contract_str) or contract_str == '':
        return 0
    contract_str = str(contract_str).replace('$', '').replace(',', '')
    nums = re.findall(r'\d+\.?\d*', contract_str)
    return float(nums[0]) if nums else 0

def match_players():
    print("Loading data files...")
    contracts_df = pd.read_csv('NFL Contracts.csv')
    test_df = pd.read_csv('PSFTESTRATINGS.csv')
    pfl_df = pd.read_csv('PFL2025DATA.csv')
    print(f"Loaded {len(contracts_df)} contracts, {len(test_df)} test players, {len(pfl_df)} PFL players")

    # Team normalizations
    contracts_df['Team_Clean'] = contracts_df['Team                     Currently With'].apply(lambda x: clean_team_name(str(x).split()[0]))
    test_df['Team_Clean'] = test_df['Team'].apply(clean_test_team_name)
    pfl_df['Team_Full'] = pfl_df['Team'].apply(clean_pfl_team_name)

    # Name/position normalizations
    contracts_df['name_key'] = contracts_df['Player'].apply(normalize_name)
    test_df['name_key'] = (test_df['firstName'] + ' ' + test_df['lastName']).apply(normalize_name)
    contracts_df['pos_norm'] = contracts_df['Pos'].apply(normalize_pos_generic)
    test_df['pos_norm'] = test_df['Position'].apply(normalize_pos_generic)

    # Primary strict key: name + team + pos
    contracts_df['key_ntp'] = contracts_df['name_key'] + '_' + contracts_df['Team_Clean'] + '_' + contracts_df['pos_norm']
    test_df['key_ntp'] = test_df['name_key'] + '_' + test_df['Team_Clean'] + '_' + test_df['pos_norm']

    # Secondary fallback: name + team (ignore pos)
    contracts_df['key_nt'] = contracts_df['name_key'] + '_' + contracts_df['Team_Clean']
    test_df['key_nt'] = test_df['name_key'] + '_' + test_df['Team_Clean']

    # Preserve original row ids to recover unmatched rows cleanly
    test_df['__row_id'] = np.arange(len(test_df))

    # Merge 1: strict
    merged1 = pd.merge(test_df, contracts_df, left_on='key_ntp', right_on='key_ntp', how='left', suffixes=('_test', '_contract'))

    # Identify unmatched (no contract Player)
    unmatched_mask = merged1['Player'].isna()
    unmatched_ids = merged1.loc[unmatched_mask, '__row_id'].tolist()

    # Get original unmatched test rows (no suffix confusion)
    unmatched_test = test_df[test_df['__row_id'].isin(unmatched_ids)].copy()

    # Merge 2: fallback by name+team
    merged2 = pd.merge(unmatched_test, contracts_df, left_on='key_nt', right_on='key_nt', how='left', suffixes=('_test', '_contract'))

    # Combine results: prefer strict match rows else fallback
    final_rows = merged1.copy()
    fallback_cols = ['Player', 'Team_Clean_contract', 'Pos', 'Value', 'Average                     Salary', 'Guarantee                     at Sign', 'Yrs']
    for col in fallback_cols:
        final_rows.loc[unmatched_mask, col] = merged2[col].values

    # Build mapping test->contract where matched
    test_to_contract = {}
    matched_count = 0
    for _, row in final_rows.iterrows():
        if pd.notna(row.get('Player')):
            test_name = f"{row['firstName']} {row['lastName']}"
            test_to_contract[test_name] = {
                'contract_value': row['Value'],
                'contract_apy': row['Average                     Salary'],
                'contract_guaranteed': row['Guarantee                     at Sign'],
                'contract_years': row['Yrs']
            }
            matched_count += 1

    print(f"Found {matched_count} matches between test data and contracts after normalization/fallbacks")

    # Build PFL<->Test match key (using full team names already normalized)
    pfl_df['match_key'] = (pfl_df['Team_Full'] + '_' + pfl_df['Position'] + '_' + pfl_df['height'].astype(str) + '_' +
                           pfl_df['weight'].astype(str) + '_' + pfl_df['age'].astype(str) + '_' + pfl_df['birthdate'])
    test_df['match_key_pfl'] = (test_df['Team'] + '_' + test_df['Position'] + '_' + test_df['height'].astype(str) + '_' +
                                 test_df['weight'].astype(str) + '_' + test_df['age'].astype(str) + '_' + test_df['birthdate'])

    pfl_merged = pd.merge(pfl_df, test_df, left_on='match_key', right_on='match_key_pfl', how='left', suffixes=('_pfl', '_test'))

    updates_made = 0
    for idx, row in pfl_merged.iterrows():
        if pd.notna(row.get('firstName_test')):
            test_name = f"{row['firstName_test']} {row['lastName_test']}"
            info = test_to_contract.get(test_name)
            if info:
                pfl_df.at[idx, 'contractYears'] = info['contract_years']
                pfl_df.at[idx, 'contractTotalValue_M'] = extract_contract_value(info['contract_value'])
                pfl_df.at[idx, 'contractAPY_M'] = extract_contract_value(info['contract_apy'])
                pfl_df.at[idx, 'contractTotalGuaranteed_M'] = extract_contract_value(info['contract_guaranteed'])
                updates_made += 1

    print(f"Updated {updates_made} players with contract information")

    output_file = 'PFL2025DATA_UPDATED.csv'
    pfl_df.to_csv(output_file, index=False)
    print(f"Saved updated data to {output_file}")

if __name__ == "__main__":
    match_players()
